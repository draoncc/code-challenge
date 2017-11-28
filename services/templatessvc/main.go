package main

import (
	"encoding/json"
	"flag"
	"io/ioutil"
	"log"
	"net"

	"google.golang.org/grpc"

	pb "github.com/draoncc/code-challenge/design"
)

var (
	addr       = flag.String("addr", "tpl-service:3000", "TCP server port")
	jsonDBFile = flag.String("db", "testdata/templates.json", "JSON file containing a list of templates")
)

func (t *templatesServer) loadTemplates(filePath string) {
	file, err := ioutil.ReadFile(filePath)
	if err != nil {
		log.Fatalf("Failed to load templates: %v", err)
	}
	if err := json.Unmarshal(file, &t.templates); err != nil {
		log.Fatalf("Failed to load templates: %v", err)
	}
}

func main() {
	flag.Parse()

	s := new(templatesServer)
	s.loadTemplates(*jsonDBFile)

	lis, err := net.Listen("tcp", *addr)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer()
	pb.RegisterTemplatesServer(grpcServer, s)
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
