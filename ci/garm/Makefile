ifeq ($(SUFFIX),)
	SUFFIX := $(shell bash -c 'echo $$RANDOM | md5sum | head -c 6')
endif
LOCATION ?= eastus
ACI_NAME := garm-$(SUFFIX)
RESOURCE_GROUP ?= replaceme
STORAGE_ACCOUNT ?= replaceme

.PHONY: deploy
deploy:
	az deployment group create \
		--template-file ./arm/aci.bicep \
		--resource-group=$(RESOURCE_GROUP) \
		--name $(ACI_NAME) \
		--parameters StorageAccount=$(STORAGE_ACCOUNT) \
		--parameters Name=$(ACI_NAME) \
		--parameters Location=$(LOCATION) \
		--parameters DnsNameLabel=$(ACI_NAME) && \
	echo $(ACI_NAME).$(LOCATION).azurecontainer.io

.PHONY: delete
delete:
	az container delete \
		--resource-group $(RESOURCE_GROUP) \
		--name garm-$(SUFFIX) \
		--yes
