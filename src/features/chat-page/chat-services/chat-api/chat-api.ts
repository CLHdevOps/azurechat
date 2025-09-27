"use server";
import "server-only";

import { getCurrentUser } from "@/features/auth-page/helpers";
import { logger } from "@/lib/logger";
import { createSpan, addTags } from "@/lib/datadog";
import { CHAT_DEFAULT_SYSTEM_PROMPT } from "@/features/theme/theme-config";
import { ChatCompletionStreamingRunner } from "openai/resources/beta/chat/completions";
import { ChatApiRAG } from "../chat-api/chat-api-rag";
import { FindAllChatDocuments } from "../chat-document-service";
import {
  CreateChatMessage,
  FindTopChatMessagesForCurrentUser,
} from "../chat-message-service";
import { EnsureChatThreadOperation } from "../chat-thread-service";
import { ChatThreadModel, UserPrompt } from "../models";
import { mapOpenAIChatMessages } from "../utils";
import { GetDefaultExtensions } from "./chat-api-default-extensions";
import { GetDynamicExtensions } from "./chat-api-dynamic-extensions";
import { ChatApiExtensions } from "./chat-api-extension";
import { ChatApiMultimodal } from "./chat-api-multimodal";
import { OpenAIStream } from "./open-ai-stream";
type ChatTypes = "extensions" | "chat-with-file" | "multimodal";

export const ChatAPIEntry = async (props: UserPrompt, signal: AbortSignal) => {
  return createSpan('chat.service.entry', {
    resource: 'ChatAPIEntry',
    service: 'azurechat'
  }, async () => {
    const chatLogger = logger.child({
      chatId: props.id,
      messageId: `msg_${Date.now()}`
    });

    chatLogger.info('Starting chat processing', {
      category: 'chat_processing',
      action: 'start',
      chatId: props.id,
      messageLength: props.message?.length || 0,
      hasMultimodal: !!props.multimodalImage,
      personaId: props.personaId
    });

    const currentChatThreadResponse = await EnsureChatThreadOperation(props.id);

    if (currentChatThreadResponse.status !== "OK") {
      chatLogger.warn('Chat thread operation failed', {
        category: 'chat_error',
        action: 'thread_operation_failed',
        errors: currentChatThreadResponse.errors
      });
      return new Response("", { status: 401 });
    }

    const currentChatThread = currentChatThreadResponse.response;

    addTags({
      'chat.thread_id': currentChatThread.id,
      'chat.user_id': currentChatThread.userId,
      'chat.persona_id': currentChatThread.personaId
    });

    // promise all to get user, history and docs
    const [user, history, docs, extension] = await Promise.all([
      getCurrentUser(),
      _getHistory(currentChatThread),
      _getDocuments(currentChatThread),
      _getExtensions({
        chatThread: currentChatThread,
        userMessage: props.message,
        signal,
      }),
    ]);

    chatLogger.info('Chat context loaded', {
      category: 'chat_processing',
      action: 'context_loaded',
      userId: user.id,
      historyCount: history.length,
      docsCount: docs.length,
      extensionsCount: extension.length
    });
    // Starting values for system and user prompt
    // Note that the system message will also get prepended with the extension execution steps. Please see ChatApiExtensions method.
    currentChatThread.personaMessage = `${CHAT_DEFAULT_SYSTEM_PROMPT} \n\n ${currentChatThread.personaMessage}`;

    let chatType: ChatTypes = "extensions";

    if (props.multimodalImage && props.multimodalImage.length > 0) {
      chatType = "multimodal";
    } else if (docs.length > 0) {
      chatType = "chat-with-file";
    } else if (extension.length > 0) {
      chatType = "extensions";
    }

    chatLogger.info('Chat type determined', {
      category: 'chat_processing',
      action: 'chat_type_determined',
      chatType,
      hasMultimodal: !!props.multimodalImage,
      docsCount: docs.length,
      extensionsCount: extension.length
    });

    // save the user message
    await CreateChatMessage({
      name: user.name,
      content: props.message,
      role: "user",
      chatThreadId: currentChatThread.id,
      multiModalImage: props.multimodalImage,
    });

    chatLogger.info('User message saved', {
      category: 'chat_processing',
      action: 'user_message_saved',
      userName: user.name
    });

    let runner: ChatCompletionStreamingRunner;

    const aiStartTime = Date.now();

    try {
      switch (chatType) {
        case "chat-with-file":
          chatLogger.azureOpenAI('rag_request_start', {
            docsCount: docs.length,
            historyCount: history.length
          });
          runner = await ChatApiRAG({
            chatThread: currentChatThread,
            userMessage: props.message,
            history: history,
            signal: signal,
          });
          break;
        case "multimodal":
          chatLogger.azureOpenAI('multimodal_request_start', {
            hasImage: !!props.multimodalImage
          });
          runner = ChatApiMultimodal({
            chatThread: currentChatThread,
            userMessage: props.message,
            file: props.multimodalImage,
            signal: signal,
          });
          break;
        case "extensions":
          chatLogger.azureOpenAI('extensions_request_start', {
            extensionsCount: extension.length,
            historyCount: history.length
          });
          runner = await ChatApiExtensions({
            chatThread: currentChatThread,
            userMessage: props.message,
            history: history,
            extensions: extension,
            signal: signal,
          });
          break;
      }

      const aiDuration = Date.now() - aiStartTime;
      chatLogger.performance('azure_openai_request', aiDuration, {
        chatType,
        success: true
      });

    } catch (error) {
      const aiDuration = Date.now() - aiStartTime;
      chatLogger.error('Azure OpenAI request failed', error, {
        category: 'azure_openai_error',
        chatType,
        duration: aiDuration
      });
      throw error;
    }

    const readableStream = OpenAIStream({
      runner: runner,
      chatThread: currentChatThread,
    });

    chatLogger.info('Chat processing completed', {
      category: 'chat_processing',
      action: 'completed',
      chatType
    });

    return new Response(readableStream, {
      headers: {
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
        "Content-Type": "text/event-stream"
      },
    });
  });
};

const _getHistory = async (chatThread: ChatThreadModel) => {
  const historyResponse = await FindTopChatMessagesForCurrentUser(
    chatThread.id
  );

  if (historyResponse.status === "OK") {
    const historyResults = historyResponse.response;
    const mappedHistory = mapOpenAIChatMessages(historyResults).reverse();

    logger.info('Chat history retrieved', {
      category: 'chat_data',
      action: 'history_retrieved',
      chatThreadId: chatThread.id,
      messageCount: mappedHistory.length
    });

    return mappedHistory;
  }

  logger.error("Error getting chat history", historyResponse.errors, {
    category: 'chat_error',
    action: 'history_retrieval_failed',
    chatThreadId: chatThread.id,
    errors: historyResponse.errors
  });

  return [];
};

const _getDocuments = async (chatThread: ChatThreadModel) => {
  const docsResponse = await FindAllChatDocuments(chatThread.id);

  if (docsResponse.status === "OK") {
    logger.info('Chat documents retrieved', {
      category: 'chat_data',
      action: 'documents_retrieved',
      chatThreadId: chatThread.id,
      documentCount: docsResponse.response.length
    });

    return docsResponse.response;
  }

  logger.error("Error retrieving chat documents", docsResponse.errors, {
    category: 'azure_service_error',
    service: 'ai_search',
    action: 'document_retrieval_failed',
    chatThreadId: chatThread.id,
    errors: docsResponse.errors
  });

  return [];
};

const _getExtensions = async (props: {
  chatThread: ChatThreadModel;
  userMessage: string;
  signal: AbortSignal;
}) => {
  const extension: Array<any> = [];

  const response = await GetDefaultExtensions({
    chatThread: props.chatThread,
    userMessage: props.userMessage,
    signal: props.signal,
  });
  if (response.status === "OK" && response.response.length > 0) {
    extension.push(...response.response);
  }

  const dynamicExtensionsResponse = await GetDynamicExtensions({
    extensionIds: props.chatThread.extension,
  });
  if (
    dynamicExtensionsResponse.status === "OK" &&
    dynamicExtensionsResponse.response.length > 0
  ) {
    extension.push(...dynamicExtensionsResponse.response);
  }

  return extension;
};
