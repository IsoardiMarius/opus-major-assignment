.PHONY: test test-race fmt fmt-check docker-build docker-run

test test-race fmt fmt-check docker-build docker-run:
	$(MAKE) -C app $@
