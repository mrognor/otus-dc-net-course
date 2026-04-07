.PHONY: image deploy destroy inspect clean

image:
	docker build -t alpine-frr:0.1 -f image_files/alpine-frr.Dockerfile .

deploy:
	containerlab deploy --reconfigure

destroy:
	containerlab destroy

inspect:
	containerlab inspect

clean:
	rm -rf clab-lab
