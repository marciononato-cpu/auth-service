# Auth Service API — Documentação

## 🌐 Base URL
- **Produção:** `https://labono.duckdns.org/api`
- **Desenvolvimento:** `http://localhost:3000/api`

---

## 🔐 Fluxo de Autenticação
A API é **stateless**. A autenticação é feita via **JWT (Bearer Token)**.
1. `POST /users` → Cadastra o usuário
2. `POST /users/confirm` → Confirma o email com código enviado
3. `POST /users/sign_in` → Obtém o `token` JWT
4. Usa `Authorization: Bearer <token>` em todas as requisições protegidas
5. `DELETE /users/sign_out` → Invalida o token (blacklist)

---

## 📡 Endpoints

### 1. Cadastro de Usuário
Cria um novo usuário e envia um código de confirmação ao email.

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `email` | string | ✅ | Email único |
| `password` | string | ✅ | Mínimo 8 caracteres |
| `password_confirmation` | string | ✅ | Deve ser igual ao `password` |

```bash
curl -X POST https://labono.duckdns.org/api/users \
  -H 'Content-Type: application/json' \
  -d '{"user": {"email": "teste@exemplo.com", "password": "Senha123!", "password_confirmation": "Senha123!"}}'
```

**Sucesso `201`:**
```json
{
  "message": "Verifique seu email e confirme o código recebido."
}
```

---

### 2. Reenviar Código de Confirmação
Reenvia o código de ativação para o email informado.

```bash
curl -X POST https://labono.duckdns.org/api/users/confirmation_code \
  -H 'Content-Type: application/json' \
  -d '{"confirmation": {"email": "teste@exemplo.com"}}'
```

**Sucesso `202`:**
```json
{
  "message": "Código de confirmação reenviado para seu email."
}
```

---

### 3. Confirmar Conta
Confirma o email com o código recebido e retorna token de login automático.

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `email` | string | ✅ | Email cadastrado |
| `code` | string | ✅ | Código numérico de 6 dígitos |

```bash
curl -X POST https://labono.duckdns.org/api/users/confirm \
  -H 'Content-Type: application/json' \
  -d '{"confirmation": {"email": "teste@exemplo.com", "code": "123456"}}'
```

**Sucesso `200`:**
```json
{
  "message": "Conta confirmada com sucesso!",
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "email": "teste@exemplo.com",
    "role": "user",
    "confirmed_at": "2024-06-24T..."
  }
}
```

---

### 4. Login
Autentica credenciais e retorna JWT.

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `email` | string | ✅ | Email cadastrado |
| `password` | string | ✅ | Senha correta |

```bash
curl -X POST https://labono.duckdns.org/api/users/sign_in \
  -H 'Content-Type: application/json' \
  -d '{"user": {"email": "teste@exemplo.com", "password": "Senha123!"}}'
```

**Sucesso `200`:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "email": "teste@exemplo.com",
    "role": "user"
  }
}
```

**Erros:**
- `401` → Credenciais inválidas
- `403` → Email não confirmado (`email_not_confirmed`)

---

### 5. Logout / Invalidar Token
Adiciona o token à blacklist (Redis). Após isso, o token não é mais válido.

```bash
curl -X DELETE https://labono.duckdns.org/api/users/sign_out \
  -H 'Authorization: Bearer <seu_token_aqui>'
```

**Sucesso `200`:**
```json
{
  "message": "Logout realizado. Token invalidado."
}
```

---

### 6. Listar Usuários (Admin)
Retorna lista paginada de todos os usuários. Acesso restrito a `role: admin`.

```bash
curl https://labono.duckdns.org/api/users \
  -H 'Authorization: Bearer <admin_token>'
```

**Sucesso `200`:**
```json
[
  {
    "id": 1,
    "email": "user@exemplo.com",
    "role": "user",
    "confirmed_at": "2024-06-24T15:00:00Z",
    "created_at": "2024-06-24T14:00:00Z",
    "updated_at": "2024-06-24T15:00:00Z"
  }
]
```

---

### 7. Remover Usuário (Admin)
Remove um usuário do sistema. Não pode remover outros admins.

```bash
curl -X DELETE https://labono.duckdns.org/api/users/1 \
  -H 'Authorization: Bearer <admin_token>'
```

**Sucesso `200`:**
```json
{
  "message": "Usuário removido com sucesso."
}
```

---

### 8. Esqueci Minha Senha
Solicita reset. Envia email com token de recuperação.

```bash
curl -X POST https://labono.duckdns.org/api/passwords \
  -H 'Content-Type: application/json' \
  -d '{"password": {"email": "usuario@exemplo.com"}}'
```

**Sucesso `202`:**
```json
{
  "message": "Instruções para redefinição enviadas ao seu email."
}
```

---

### 9. Resetar Senha
Usa o token recebido por email para definir uma nova senha.

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `token` | string | ✅ | Token enviado por email |
| `password` | string | ✅ | Nova senha |
| `password_confirmation` | string | ✅ | Confirmar nova senha |

```bash
curl -X PATCH https://labono.duckdns.org/api/passwords \
  -H 'Content-Type: application/json' \
  -d '{"password": {"token": "abc123def456...", "password": "NovaSenha456!", "password_confirmation": "NovaSenha456!"}}'
```

**Sucesso `200`:**
```json
{
  "message": "Senha redefinida com sucesso. Faça login novamente."
}
```

---

## ⚠️ Tratamento de Erros
Todos os erros seguem formato padrão:
```json
{
  "error": "message_resumo",
  "errors": ["detalhe_1", "detalhe_2"]
}
```
**Códigos HTTP frequentes:**
| Código | Significado |
|--------|-------------|
| `201` | Criado com sucesso |
| `200` | OK / Sucesso |
| `202` | Aceito (processamento assíncrono, ex: email) |
| `400` | Request malformado ou campos inválidos |
| `401` | Token ausente, inválido ou credenciais erradas |
| `403` | Acesso negado (email não confirmado, role insuficiente) |
| `404` | Recurso não encontrado |
| `422` | Validação falhou (ex: email duplicado) |
| `429` | Rate limit excedido |
| `500` | Erro interno do servidor |

---

## ⏱️ Rate Limiting
Limites aplicados por IP via Redis:
| Endpoint | Limite | Janela |
|----------|--------|--------|
| `POST /users/sign_in` | 5 | 1 minuto |
| `POST /users/confirmation_code` | 3 | 1 minuto |
| `POST /passwords` (forgot) | 2 | 1 minuto |
| `POST /users` | 3 | 1 minuto |
| Demais rotas | 30 | 1 minuto |

---

## 🔒 Segurança
- ✅ **JWT Stateless** com expiração configurável (`JWT_CONFIG[:expiry]`)
- ✅ **Blacklist de Tokens** via Redis (logout invalida imediatamente)
- ✅ **Hash de Senha** via `has_secure_password` (bcrypt)
- ✅ **Confirmação Obrigatória** de email antes do login
- ✅ **Rate Limiting** anti-brute-force por IP
- ✅ **Mensagens Genéricas** (não enumera emails existentes)
- ✅ **CORS Liberado** para desenvolvimento (ajuste em produção)
- ✅ **Sanitização Global** de erros (sem vazamento de stack trace)

---

## 📦 Integração Futura
Esta API é **stateless e agnóstica a frontend**. Pode ser consumida por:
- 📱 **Apps Mobile** (React Native, Flutter, Swift, Kotlin)
- 🌐 **SaaS/Web** (Next.js, Vue, Angular, SPA estática)
- 🤖 **Microserviços** (HTTP REST)

Basta armazenar o `token` retornado no `localStorage` (web) ou `secure storage` (mobile) e enviar no header `Authorization: Bearer <token>`.

---
*Documentação gerada em 24/06/2026 — Auth Service v1.0*
