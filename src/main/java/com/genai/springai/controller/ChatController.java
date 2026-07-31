package com.genai.springai.controller;

import com.genai.springai.dto.ChatRequest;
import com.genai.springai.service.ChatService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    @GetMapping
    public String chat(@RequestParam String message) {
        return chatService.ask(message);
    }

    @PostMapping("/context")
    public String chatWithContext(@RequestBody ChatRequest request) {
        return chatService.askWithParams(request.question(), request.context());
    }
}