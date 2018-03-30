OUTPUT_DIR := $(CURDIR)/output

.PHONY: build clean

build: clean
	$(CURDIR)/build.sh

clean:
	rm -rf $(OUTPUT_DIR)/*

#deploy:
#	$(CURDIR)/deploy.sh

