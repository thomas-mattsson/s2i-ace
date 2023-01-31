IMAGE_NAME = s2i-ace

.PHONY: build
build:
	podman build -t $(IMAGE_NAME) .

.PHONY: test
test:
	podman build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=localhost/$(IMAGE_NAME)-candidate test/run
