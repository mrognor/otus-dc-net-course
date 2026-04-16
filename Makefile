.PHONY: deploy destroy inspect images clean

-include .conf

deploy:
	containerlab deploy --reconfigure -t labs/$(LAB)/lab.clab.yaml
	@echo "LAB=$(LAB)" > .conf

destroy:
	containerlab destroy -t labs/$(LAB)/lab.clab.yaml

inspect:
	containerlab inspect -t labs/$(LAB)/lab.clab.yaml

images:
	docker build -t alpine-frr-switch:0.1 -f image_files/alpine-frr-switch.Dockerfile .
	docker build -t alpine-frr-client:0.1 -f image_files/alpine-frr-client.Dockerfile .

clean:
	rm .conf
	rm -rf labs/lab*/clab-lab
