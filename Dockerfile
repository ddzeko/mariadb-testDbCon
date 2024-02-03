FROM python:3.11-slim

WORKDIR /app

ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Build environment for Python module "mariadb"
RUN apt update
RUN apt install -y wget gcc libc6-dev --no-install-recommends

# Since we need a specific version of library which might not be available from the APT repo
RUN mkdir /tmp/connector
ENV MCCV=3.3.5
RUN wget https://downloads.mariadb.com/Connectors/c/connector-c-$MCCV/mariadb-connector-c-$MCCV-ubuntu-bionic-amd64.tar.gz --directory /tmp/connector
RUN tar -zxpf /tmp/connector/mariadb-connector-c-$MCCV-ubuntu-bionic-amd64.tar.gz --directory /tmp/connector
RUN mv -f /tmp/connector/mariadb-connector-c-$MCCV-ubuntu-bionic-amd64/bin/mariadb_config /usr/bin/
RUN mv -f /tmp/connector/mariadb-connector-c-$MCCV-ubuntu-bionic-amd64/include/mariadb /usr/include/
RUN mv -f /tmp/connector/mariadb-connector-c-$MCCV-ubuntu-bionic-amd64/lib/mariadb /usr/lib/
RUN find /usr/lib/mariadb -maxdepth 1 -name lib\* -type f,l | xargs cp -a --target-directory=/usr/lib

# Dependencies for libmariadb3
RUN apt-cache depends libmariadb3 | awk '/Depends:/{print $2}' | xargs apt -y install --no-install-recommends
RUN mkdir /tmp/libssl
# if the link below does not work, check online what's the current one
RUN wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.20_amd64.deb --directory /tmp/libssl
RUN dpkg --install /tmp/libssl/*.deb
RUN ldconfig

# Python Environment setup
RUN pip3 install --no-cache-dir --upgrade pip
RUN pip3 install --no-cache-dir --upgrade setuptools

# Install dependencies:
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Run the application:
COPY --chmod=0755 testDbCon.py .
CMD ["python", "testDbCon.py"]

