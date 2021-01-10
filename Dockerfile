FROM google/cloud-sdk:latest
COPY --from=hashicorp/terraform:0.14.4 /bin/terraform /bin/
COPY . .
RUN terraform init
# etc
