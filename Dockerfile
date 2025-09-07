FROM python:3.10.18-bookworm

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY gcp_wif_test.py ./
COPY aws_security_credentials_supplier.py ./

CMD [ "python", "gcp_wif_test.py" ]
