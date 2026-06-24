# Fluxo de Autenticação - auth-service

## 📋 Resumo
Backend Rails 8.1.3 com autenticação JWT, rate limiting, confirmação de email e sistema dual-admin.

## 🔑 Admins Configurados
- **Admin Principal**: labonops_1782331150@at.com (simulação labonosp@gmail.com)
- **Admin Secundário**: marciononato@hotmail.com (seu email pessoal)
- **Senha**: Admin123!
- **Role**: admin (ambos)

## 📝 Fluxo Completo

### 1. Cadastro (POST /users)
```bash
curl -X POST http://localhost:3000/users \
  -H 'Content-Type: application/json' \
  -d '{"user":{"email":"email@teste.com","password":"Admin123!","password_confirmation":"Admin123!"}}'
```
**Resposta esperada**: 201 - Conta criada com código de confirmação gerado

### 2. Bloqueio pré-confirmação (POST /users/sign_in)
```bash
curl -X POST http://localhost:3000/users/sign_in \
  -H 'Content-Type: application/json' \
  -d '{"user":{"email":"email@teste.com","password":"Admin123!"}}'
```
**Resposta esperada**: 403 - `{"error": "email_not_confirmed"}`

### 3. Confirmação por código (POST /users/confirm)
```bash
curl -X POST http://localhost:3000/users/confirm \
  -H 'Content-Type: application/json' \
  -d '{"confirmation":{"email":"email@teste.com","code":"123456"}}'
```
**Resposta esperada**: 200 - Conta confirmada com token JWT

### 4. Login (POST /users/sign_in)
```bash
curl -X POST http://localhost:3000/users/sign_in \
  -H 'Content-Type: application/json' \
  -d '{"user":{"email":"email@teste.com","password":"Admin123!"}}'
```
**Resposta esperada**: 200 - `{"token": "eyJhbG...", "user": {...}}`

### 5. Acesso protegido (GET /users)
```bash
curl http://localhost:3000/users \
  -H 'Authorization: Bearer <TOKEN>'
```
**Resposta esperada**: 200 - Lista de usuários (apenas admins)

### 6. Logout (DELETE /users/sign_out)
```bash
curl -X DELETE http://localhost:3000/users/sign_out \
  -H 'Authorization: Bearer <TOKEN>'
```
**Resposta esperada**: 200 - Token adicionado à blacklist do Redis

## 🛡️ Segurança Implementada

### Rate Limiting
- Login: 5 tentativas/minuto
- Confirmação: 3 tentativas/minuto
- Reset senha: 2 tentativas/minuto

### JWT
- Algoritmo: HS256
- Expiração: 24h
- Blacklist: Redis (DB 0)
- Secret key: configurado em `config/initializers/jwt.rb`

### Middleware Stack
1. **RateLimitingMiddleware** - protege contra abusos
2. **AuthMiddleware** - valida tokens JWT
3. **CORS** - controla origens permitidas

### Rotas Públicas vs Protegidas

**Públicas (sem token):**
- POST /users (cadastro)
- POST /users/sign_in (login)
- POST /users/confirm (confirmação)
- POST /users/confirm/resend (reenviar código)
- POST /passwords (forgot password)
- PATCH /passwords (reset password)
- PUT /passwords
- GET /up (health check)

**Protegidas (com token):**
- GET /users (lista usuários - admin apenas)
- DELETE /users/:id (remove usuário - admin apenas)
- DELETE /users/sign_out (logout)

## 🔍 Troubleshooting

### Erro "Credenciais inválidas" (401)
- Verificar se o email existe no banco
- Confirmar que a senha está correta
- Checar se o email foi confirmado

### Erro "Token não fornecido" (401)
- Verificar header Authorization
- Formato: `Bearer <token>`
- Sem espaço entre "Bearer" e o token

### Erro "Acesso negado" (403)
- Verificar role do usuário (precisa ser 'admin')
- Verificar se token não expirou
- Verificar se token não está na blacklist

### Redis indisponível
- Verificar se Redis está rodando: `redis-cli ping`
- Deve responder com PONG
- DB 0 = JWT blacklist/cache
- DB 1 = Rate limiting

### Servidor não sobe
- Verificar porta 3000 livre: `lsof -ti:3000`
- Verificar variáveis de ambiente: `cat .env`
- Verificar logs: `tail -f log/production.log`

## 📊 Status Atual
- ✅ Servidor rodando em produção (porta 3000)
- ✅ Redis conectado (127.0.0.1:6379)
- ✅ PostgreSQL conectado (auth_user@127.0.0.1)
- ✅ SMTP configurado (labonosp@gmail.com)
- ✅ Autenticação JWT funcional
- ✅ Rate limiting ativo
- ✅ Dois admins configurados
- ✅ Testes end-to-end validados
