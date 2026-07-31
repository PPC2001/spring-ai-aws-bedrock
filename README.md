# 🤖 Spring AI AWS Bedrock Integration

A modern Spring Boot application demonstrating GenAI / LLM capabilities using **Spring AI 2.0.0**, **AWS Bedrock (Converse API)**, **Java 26**, and **Lombok**.

---

## 🚀 Tech Stack

| Technology | Version | Description |
| :--- | :--- | :--- |
| **Java** | `26` | Modern Java Development Kit |
| **Spring Boot** | `4.1.0` | Enterprise Application Framework |
| **Spring AI** | `2.0.0` | Unified Framework for Generative AI |
| **AWS Bedrock** | Converse API | Managed Foundation Models (`amazon.nova-lite-v1:0` / Claude) |
| **Lombok** | `1.18.x` | Code Generation & Boilerplate Reduction |
| **Build Tool** | Maven | Build Tool & Dependency Management |

> 💡 **For Infrastructure, Docker & AWS ECS/ALB Deployment**: Please refer to the dedicated [DEVOPS_README.md](./DEVOPS_README.md).

---

## 📁 Application Package Structure

```
springai-app/
├── pom.xml                                     # Project Dependencies & Java 26 Setup
└── src/
    └── main/
        ├── java/com/genai/springai/
        │   ├── SpringaiAppApplication.java     # Main Entrypoint
        │   ├── config/
        │   │   └── ChatConfig.java             # Spring AI ChatClient Bean
        │   ├── controller/
        │   │   └── ChatController.java         # REST Endpoints (/api/chat)
        │   ├── dto/
        │   │   └── ChatRequest.java            # DTO Record for contextual prompts
        │   └── service/
        │       └── ChatService.java            # Bedrock LLM Business Logic
        └── resources/
            └── application.properties         # Model & Actuator Configuration
```

---

## ⚙️ Application Configuration

Application properties are declared in [`src/main/resources/application.properties`](file:///c:/Users/Pratik/Downloads/springai-app/springai-app/src/main/resources/application.properties) with dynamic environment variable overrides:

```properties
spring.application.name=springai-app
spring.profiles.active=${SPRING_PROFILES_ACTIVE:dev}

# AWS Bedrock Region Configuration
spring.ai.bedrock.aws.region=${AWS_REGION:ap-south-1}

# Bedrock Converse Chat Model Configuration
spring.ai.bedrock.converse.chat.options.model=${BEDROCK_MODEL_ID:amazon.nova-lite-v1:0}
spring.ai.bedrock.converse.chat.options.temperature=${BEDROCK_TEMPERATURE:0.7}
spring.ai.bedrock.converse.chat.options.max-tokens=${BEDROCK_MAX_TOKENS:1024}

# Server Port
server.port=${PORT:8080}

# Spring Boot Actuator Exposure
management.endpoints.web.exposure.include=health
management.endpoint.health.show-details=always
```

---

## 🛠️ Local Development & Running

### 1. Prerequisites
- **Java 26** (or Java 21 LTS) installed locally.
- **AWS Credentials** configured with model access to AWS Bedrock in `ap-south-1` or `us-east-1`.

### 2. Set AWS Environment Variables

#### On Windows (PowerShell):
```powershell
$env:AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_KEY"
$env:AWS_REGION="ap-south-1"
```

#### On Linux / macOS:
```bash
export AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_KEY"
export AWS_REGION="ap-south-1"
```

### 3. Build & Run
```bash
# Compile and build package
./mvnw clean package -DskipTests

# Run the Spring Boot application
./mvnw spring-boot:run
```
The application starts by default on `http://localhost:8080`.

---

## 📡 REST API Endpoints

### 1. Basic Prompt Endpoint
Sends a question to AWS Bedrock Converse model and returns the text response.

- **Method**: `GET`
- **Path**: `/api/chat`
- **Query Parameter**: `message` (String)

#### Example Request:
```bash
curl "http://localhost:8080/api/chat?message=Explain+Spring+AI+in+two+sentences"
```

---

### 2. Context-Aware Prompt Endpoint
Sends a question along with additional context data to guide the LLM.

- **Method**: `POST`
- **Path**: `/api/chat/context`
- **Header**: `Content-Type: application/json`

#### Payload Schema (`ChatRequest`):
```json
{
  "question": "What is our return window?",
  "context": "Our store policy allows returns within 30 days of purchase with a valid receipt."
}
```

#### Example Request:
```bash
curl -X POST "http://localhost:8080/api/chat/context" \
     -H "Content-Type: application/json" \
     -d '{
           "question": "What is our return window?",
           "context": "Our store policy allows returns within 30 days of purchase with a valid receipt."
         }'
```

---

### 3. Health Check Endpoint
Used by monitoring and AWS Load Balancers to verify application health.

- **Method**: `GET`
- **Path**: `/actuator/health`

#### Example Response:
```json
{
  "status": "UP"
}
```

---

## 🔗 Related Documentation
- 🛠️ [DEVOPS_README.md](./DEVOPS_README.md) - Complete guide for Docker, AWS ECS Fargate, ALB, ECR, IaC, and GitHub Actions CI/CD Pipeline.
