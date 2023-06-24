FROM golang

RUN go install github.com/x-motemen/blogsync@v0.13.5

ENTRYPOINT [ "blogsync" ]
