FROM codercom/code-server:4.145.2

ARG TERRAFORM_VERSION=1.6.6
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 jq unzip curl vim nano less \
 && rm -rf /var/lib/apt/lists/* \
 && arch=$(dpkg --print-architecture) \
 && curl -fsSLo /tmp/tf.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${arch}.zip" \
 && unzip -o /tmp/tf.zip terraform -d /usr/local/bin \
 && curl -fsSLo /tmp/aws.zip "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" \
 && unzip -q /tmp/aws.zip -d /tmp && /tmp/aws/install \
 && rm -rf /tmp/*

ENV TF_PLUGIN_CACHE_DIR=/opt/tf-plugin-cache \
    AWS_ACCESS_KEY_ID=test \
    AWS_SECRET_ACCESS_KEY=test \
    AWS_REGION=us-east-1 \
    AWS_DEFAULT_REGION=us-east-1 \
    AWS_ENDPOINT_URL=http://moto:5000

COPY warm /tmp/warm
RUN mkdir -p $TF_PLUGIN_CACHE_DIR && for d in /tmp/warm/*; do terraform -chdir=$d init -backend=false -input=false || exit 1; done \
 && rm -rf /tmp/warm && mkdir -p /opt/code-server-ext \
 && chown -R coder:coder $TF_PLUGIN_CACHE_DIR /opt/code-server-ext

USER coder
RUN code-server --extensions-dir /opt/code-server-ext --install-extension hashicorp.terraform
COPY --chown=coder:coder settings.json /home/coder/.local/share/code-server/User/settings.json
COPY grader.py entrypoint.sh /opt/grader/
COPY labs /opt/labs
RUN mkdir -p /home/coder/lab

EXPOSE 8080 7000
ENTRYPOINT ["/opt/grader/entrypoint.sh"]
