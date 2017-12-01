FROM golang:1.9.2

WORKDIR /go/src/app

ADD services/templatessvc .
ADD services/templatessvc/testdata ../../bin

RUN go-wrapper download
RUN go-wrapper install

WORKDIR /go/bin

EXPOSE 3000
CMD [ "./app", "-db", "./templates.json" ]
