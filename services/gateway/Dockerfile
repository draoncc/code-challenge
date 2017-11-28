FROM golang:1.9.2

WORKDIR /go/src/app

ADD services/gateway .

RUN go-wrapper download
RUN go-wrapper install

WORKDIR /go/bin

EXPOSE 8080
CMD [ "./app" ]
