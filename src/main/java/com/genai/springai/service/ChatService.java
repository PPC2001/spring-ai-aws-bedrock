package com.genai.springai.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class ChatService {

    private final ChatClient chatClient;

    public String ask(String question) {
        log.info("Sending prompt to Bedrock: {}", question);

        return chatClient.prompt()
                .system("You are a concise backend engineering assistant.")
                .user(question)
                .call()
                .content();
    }

    public String askWithParams(String question, String context) {
        return chatClient.prompt()
                .system(s -> s.text("You answer using only the given context: {context}")
                        .param("context", context))
                .user(question)
                .call()
                .content();
    }
}