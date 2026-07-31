# Spring AI AWS Bedrock Integration

A modern Spring Boot application demonstrating GenAI / LLM capabilities using **Spring AI 2.0.0**, **AWS Bedrock (Converse API)**, **Java 26**, and **Lombok**.

---

## 🚀 Tech Stack

| Technology | Version | Description |
| :--- | :--- | :--- |
| **Java** | `26` | Modern JDK |
| **Spring Boot** | `4.1.0` | Application Framework |
| **Spring AI** | `2.0.0` | Unified AI Framework for Java |
| **AWS Bedrock** | Converse API | Foundation Models (Claude 3.5 Sonnet) |
| **Lombok** | `1.18.x` | Boilerplate Code Reduction |
| **Build Tool** | Maven | Dependency Management & Build |

---

## 📁 Project Architecture & Package Structure

```
springai-app/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/com/genai/springai/
│   │   │   ├── SpringaiAppApplication.java   # Spring Boot Main Entrypoint
│   │   │   ├── config/
│   │   │   │   └── ChatConfig.java            # ChatClient Bean Configuration
│   │   │   ├── controller/
│   │   │   │   └── ChatController.java        # REST API Endpoints
│   │   │   ├── dto/
│   │   │   │   └── ChatRequest.java           # DTO Record for context requests
│   │   │   └── service/
│   │   │       └── ChatService.java           # Bedrock LLM Business Logic
│   │   └── resources/
│   │       └── application.properties         # AWS & Spring AI Configuration
```

---

## ⚙️ Configuration & Prerequisites

### 1. AWS Credentials
To connect to AWS Bedrock, ensure you have enabled model access in your AWS Console (e.g. **Anthropic Claude 3.5 Sonnet**) and set your AWS environment variables:

#### On Windows (PowerShell):
```powershell
$env:AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_KEY"
$env:AWS_REGION="us-east-1"
```

#### On Linux / macOS:
```bash
export AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_KEY"
export AWS_REGION="us-east-1"
```

### 2. Application Properties Configuration
The application parameters are configured in [`src/main/resources/application.properties`](file:///c:/Users/Pratik/Downloads/springai-app/springai-app/src/main/resources/application.properties):

```properties
spring.application.name=springai-app
spring.profiles.active=dev

# AWS Region Configuration
spring.ai.bedrock.aws.region=${AWS_REGION:us-east-1}

# Bedrock Model Configuration
spring.ai.bedrock.converse.chat.options.model=anthropic.claude-3-5-sonnet-20241022-v2:0
spring.ai.bedrock.converse.chat.options.temperature=0.7
spring.ai.bedrock.converse.chat.options.max-tokens=1024
```

---

## 🛠️ How to Build and Run

### Build the Project
```bash
mvn clean compile
```

### Run the Application
```bash
mvn spring-boot:run
```
The application starts by default on port `8080`.

---

## 📡 REST API Documentation

### 1. Basic Prompt Endpoint

Sends a direct message/question to AWS Bedrock Converse model.

- **Method**: `GET`
- **Path**: `/api/chat`
- **Query Parameter**: `message` (String)

#### Example Request:
```bash
curl "http://localhost:8080/api/chat?message=Explain+Spring+AI+in+two+sentences"
```

---

### 2. Context-Aware Prompt Endpoint

Sends a question along with specific context data to guide the LLM's answer.

- **Method**: `POST`
- **Path**: `/api/chat/context`
- **Header**: `Content-Type: application/json`

#### Request Payload ([ChatRequest](file:///c:/Users/Pratik/Downloads/springai-app/springai-app/src/main/java/com/genai/springai/dto/ChatRequest.java)):
```json
{
  "question": "What is our store's return window?",
  "context": "Our store allows returns within 30 days of purchase with a valid receipt."
}
```

#### Example Request:
```bash
curl -X POST "http://localhost:8080/api/chat/context" \
     -H "Content-Type: application/json" \
     -d '{
           "question": "What is our store's return window?",
           "context": "Our store allows returns within 30 days of purchase with a valid receipt."
         }'
```

---

## 📄 License
This project is licensed under the MIT License.
