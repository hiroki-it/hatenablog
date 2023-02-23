FROM golang

RUN go install github.com/x-motemen/blogsync@v0.13.0

ENTRYPOINT [ "blogsync" ]
