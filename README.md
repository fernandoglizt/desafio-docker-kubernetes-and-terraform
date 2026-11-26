# Mural de Recados

## Kubernetes local

Com Docker rodando e Terraform instalado, execute a partir da raiz.

```sh
terraform -chdir=infra/terraform init
terraform -chdir=infra/terraform apply
terraform -chdir=infra/terraform output -raw url
```

Abra o endereço exibido, por padrão `http://mural.localtest.me:8080`. Se o DNS local bloquear esse domínio, rode `terraform -chdir=infra/terraform apply -var='ingress_host='` e abra `http://127.0.0.1:8080`. As portas do cluster ficam vinculadas ao loopback.

O Terraform cria o cluster kind, monta as imagens e as carrega no nó. Depois instala o Traefik e o chart no namespace `mural`. O Ingress envia `/api` para a API e `/` para o nginx. As tags das imagens dependem do conteúdo de cada build.

O Postgres guarda os recados em um PVC. O Job executa os SQLs em ordem e em uma transação. Enquanto a tabela não existir, `/readyz` mantém a API fora do balanceamento. A liveness usa `/healthz`. A senha vem de um Secret gerado na instalação. Mantenha o state do Terraform fora do Git, pois ele contém a senha e as credenciais do cluster.

O comando abaixo remove o cluster, o chart e as imagens da aplicação.

```sh
terraform -chdir=infra/terraform destroy
```

## Compose de desenvolvimento

Escolha uma senha local alfanumérica e exporte-a na variável `MURAL_DB_PASSWORD`. O Compose roda o Go a partir do código e espera a migração terminar antes de iniciar a API.

```sh
docker compose up -d --wait
curl -fsS http://127.0.0.1:8080/api/messages
docker compose down
```

## Validação

No Docker ARM64, `docker image inspect` reportou 75.129.251 bytes para `golang:1.23-alpine` no Compose e 3.123.165 bytes para a imagem final da API. O binário estático em `scratch` reduziu o tamanho em 95,8%.

O primeiro `terraform apply` criou 9 recursos. O segundo registrou `0 added, 0 changed, 0 destroyed`. Publiquei um recado pelo Ingress e confirmei que ele continuava disponível após recriar o pod do Postgres.

O `terraform destroy` removeu os 9 recursos. Depois, validei o Compose em separado. A migração terminou antes da API, e o nginx devolveu o recado inicial pelo caminho `/api/messages`.
