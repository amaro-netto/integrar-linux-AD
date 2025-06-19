# 🖥️ Autenticação Linux com Active Directory

### Pré-requisitos

- Ter o nome do domínio AD (ex: `empresa.local`)
- Ter o IP ou nome do servidor AD
- Ter um usuário administrador do domínio para conectar

---

## 🧩 ETAPA 1 – Preparar o sistema

### ✅ Passo 1.1: Verifique o nome do seu computador

Ele precisa ter um nome identificável pela rede:

```bash
hostnamectl set-hostname maquina01
```

### ✅ Passo 1.2: Sincronize o horário

O Active Directory exige horário sincronizado, ou a autenticação vai falhar.

```bash
sudo apt update
sudo apt install chrony -y
```

Edite o arquivo do chrony:

```bash
sudo nano /etc/chrony/chrony.conf
```

Adicione seu servidor AD (exemplo com IP 192.168.1.10):

```
server 192.168.1.10 iburst
```

Salve e reinicie:

```bash
sudo systemctl restart chronyd
```

---

## 🧩 ETAPA 2 – Instalar os pacotes necessários

```bash
sudo apt update
sudo apt install realmd sssd sssd-tools libnss-sss libpam-sss adcli oddjob oddjob-mkhomedir samba-common-bin krb5-user packagekit -y
```

Durante a instalação, pode aparecer a pergunta sobre o REALM do Kerberos.  
Coloque seu domínio em MAIÚSCULAS, por exemplo:

```
EXEMPLO.LOCAL
```
---

## 🧩 ETAPA 3 – Descobrir o domínio Active Directory

Use o comando abaixo com o nome do seu domínio (em maiúsculas ou minúsculas, tanto faz):

```bash
realm discover exemplo.local
```

Você deve ver uma saída parecida com:

```yaml
exemplo.local
  type: kerberos
  realm-name: EXEMPLO.LOCAL
  domain-name: exemplo.local
  configured: no
  ...
```

---

## 🧩 ETAPA 4 – Entrar no domínio

Substitua os seguintes itens:

- `Administrador`: um usuário com permissão no domínio
- `exemplo.local`: o nome do seu domínio

```bash
sudo realm join --user=Administrador exemplo.local
```

O sistema vai pedir a senha do usuário do domínio.

✅ Se tudo der certo, você **não verá erros** e o Linux já estará autenticado no domínio.

---

## 🧩 ETAPA 5 – Testar se o domínio está funcionando

Verifique se o domínio está conectado:

```bash
realm list
```

Você verá um bloco com informações do domínio.

Agora teste buscar um usuário:

```bash
id usuario@exemplo.local
```

Substitua `usuario` por um usuário real do AD.  
✅ Se aparecerem informações como UID e grupos: **Sucesso!**

---

## 🧩 ETAPA 6 – Permitir apenas certos usuários (opcional)

Por padrão, **qualquer usuário do AD pode logar**. Para restringir o acesso apenas a um grupo específico:

```bash
sudo realm permit --groups "TI"
```

Apenas usuários do grupo **TI** (no AD) poderão logar no Linux.

---

## 🧩 ETAPA 7 – Criar pastas home automaticamente

Sem isso, o usuário do AD loga, mas **não terá uma pasta pessoal**.

Ative com:

```bash
sudo pam-auth-update --enable mkhomedir
```

---

## 🧩 ETAPA 8 – Melhorar nomes dos usuários

Por padrão, você precisa logar como:

```bash
usuario@exemplo.local
```

Se quiser permitir login **somente com o nome do usuário**, edite:

```bash
sudo nano /etc/sssd/sssd.conf
```

Adicione ou altere estas linhas:

```ini
use_fully_qualified_names = False
fallback_homedir = /home/%u
```

Salve o arquivo, corrija permissões e reinicie o serviço:

```bash
sudo chmod 600 /etc/sssd/sssd.conf
sudo systemctl restart sssd
```

---

## 🧪 TESTE FINAL

Deslogue e, na tela de login do Linux, tente entrar com um usuário do AD:

- **Usuário:** `usuario`
- **Senha:** *(senha do AD)*

✅ Se logar e for levado à área de trabalho com uma pasta `/home/usuario`, **tudo está funcionando perfeitamente!**

---

## 🔐 Extras de segurança (opcional)

### Bloquear logins fora do domínio

Para permitir **apenas logins via AD**:

```bash
sudo realm deny --all
sudo realm permit --groups TI
```

---

## 🧰 DICA FINAL – Diagnóstico se algo der errado

Execute estes comandos para investigar problemas:

```bash
journalctl -xe | grep sssd
realm discover exemplo.local
realm join --verbose --user=Administrador exemplo.local
```
