OUTPUT_DIR := $(CURDIR)/output

.PHONY: build clean

build:
	$(MAKE) clean
	$(CURDIR)/build.sh

clean:
	rm -rf $(OUTPUT_DIR)/*

#deploy:
#	$(CURDIR)/deploy.sh

