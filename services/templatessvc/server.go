package main

import (
	"context"
	"errors"

	"github.com/gogo/protobuf/proto"

	pb "github.com/draoncc/code-challenge/design"
)

type templatesServer struct {
	templates []*pb.Template
}

func (t *templatesServer) GetTemplate(ctx context.Context, id *pb.UUID) (*pb.Template, error) {
	for _, template := range t.templates {
		if proto.Equal(template.Id, id) {
			return template, nil
		}
	}

	return nil, errors.New("not found")
}

func (t *templatesServer) GetTemplateChain(id *pb.UUID, stream pb.Templates_GetTemplateChainServer) error {
	for _, template := range t.templates {
		if proto.Equal(template.Id, id) {
			if err := stream.Send(template); err != nil {
				return err
			}
		}
	}

	return nil
}

func (t *templatesServer) HasTemplate(ctx context.Context, id *pb.UUID) (*pb.Boolean, error) {
	for _, template := range t.templates {
		if proto.Equal(template.Id, id) {
			return &pb.Boolean{Value: true}, nil
		}
	}

	return &pb.Boolean{Value: false}, nil
}
