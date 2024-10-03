# TODO(cdzombak): set shell

# TODO(cdzombak): help target

.PHONY: pod-install
pods: ## run pod install
	./vendor/bundle/ruby/3.3.0/bin/pod install
