package main

import (
	"context"
	"flag"

	"github.com/yarf-framework/yarf"
	"google.golang.org/grpc"

	pb "github.com/draoncc/code-challenge/design"
)

var (
	addr             = flag.String("addr", "localhost:8080", "HTTP server port")
	tplsvcServerAddr = flag.String("tplsvc_addr", "tpl-service:3000", "Template service address")
)

type templateResource struct {
	yarf.Resource
}

func (t *templateResource) Get(c *yarf.Context) error {
	id := c.Param("id")

	// Connect to RPC Server
	//
	// Usually you would want to do this once as the server starts,
	// and poll if the connection is interrupted.
	conn, err := grpc.Dial(*tplsvcServerAddr, grpc.WithInsecure())
	if err != nil {
		panic(err)
	}
	defer conn.Close()

	// Create client to consume RPC API
	client := pb.NewTemplatesClient(conn)

	// Check if template exists
	ok, err := client.HasTemplate(context.Background(), &pb.UUID{Value: id})
	if err != nil {
		return yarf.ErrorUnexpected()
	}

	if !ok.Value {
		return yarf.ErrorNotFound()
	}

	// Fetch the template
	json, err := client.GetTemplate(context.Background(), &pb.UUID{Value: id})
	if err != nil {
		return yarf.ErrorUnexpected()
	}

	// Render the fetched template
	c.RenderJSON(json)
	return nil
}

func main() {
	flag.Parse()

	t := new(templateResource)

	y := yarf.New()
	y.Add("/:id", t)
	y.Start(*addr)
}
