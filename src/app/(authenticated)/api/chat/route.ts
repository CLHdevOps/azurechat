import { ChatAPIEntry } from "@/features/chat-page/chat-services/chat-api/chat-api";
import { UserPrompt } from "@/features/chat-page/chat-services/models";
import { createRequestLogger } from "@/lib/logger";
import { createSpan } from "@/lib/datadog";

export async function POST(req: Request) {
  const requestLogger = createRequestLogger(req);
  const startTime = Date.now();

  return createSpan('chat.api.post', { resource: '/api/chat', service: 'azurechat' }, async () => {
    try {
      requestLogger.info('Processing chat request', {
        category: 'api_request',
        endpoint: '/api/chat',
        method: 'POST'
      });

      const formData = await req.formData();
      const content = formData.get("content") as unknown as string;
      const multimodalImage = formData.get("image-base64") as unknown as string;

      const userPrompt: UserPrompt = {
        ...JSON.parse(content),
        multimodalImage,
      };

      requestLogger.chatEvent('chat_request_received', {
        chatId: userPrompt.id,
        messageLength: userPrompt.message?.length || 0,
        hasImage: !!multimodalImage,
        hasPersona: !!userPrompt.personaId,
        hasExtensions: Array.isArray(userPrompt.extension) && userPrompt.extension.length > 0
      });

      const response = await ChatAPIEntry(userPrompt, req.signal);

      const duration = Date.now() - startTime;
      requestLogger.performance('chat_api_request', duration, {
        chatId: userPrompt.id,
        success: response.ok
      });

      requestLogger.info('Chat request completed', {
        category: 'api_response',
        endpoint: '/api/chat',
        status: response.status,
        duration
      });

      return response;
    } catch (error) {
      const duration = Date.now() - startTime;
      requestLogger.error('Chat request failed', error, {
        category: 'api_error',
        endpoint: '/api/chat',
        duration
      });
      throw error;
    }
  });
}
