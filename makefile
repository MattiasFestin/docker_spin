pre:
	alias docker="(hash podman && podman) || docker"

build: pre
	docker build -t spin_runtime .

run: pre
	docker run -d --privileged -p 4646:4646 -p 8500:8500 -p 8200:8200 -p 8081:8081 -p 8080:8080 -p 80:80 --name fermyon_client spin_runtime