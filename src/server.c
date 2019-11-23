#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <include/kbag.h>

#define MY_PORT		12345
#define MAXBUF		96

int server(void)
{
	int sockfd = 0;
	int clientfd = 0;
	int enable = 1;
	char buffer[MAXBUF];
	struct sockaddr_in server;
	struct sockaddr_in client_addr;
	size_t receiver = 0;
	socklen_t addrlen = 0;
	char *key = NULL;

	sockfd = socket(AF_INET, SOCK_STREAM, 0);
	if (sockfd < 0 ) {
		perror("Socket");
		return -1;
	}

	if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int)) < 0) {
		perror("setsockopt()");
		return -1;
	}

	bzero(&server, sizeof(server));
	server.sin_family = AF_INET;
	server.sin_port = htons(MY_PORT);
	server.sin_addr.s_addr = INADDR_ANY;

	if (bind(sockfd, (struct sockaddr*)&server, sizeof(server)) != 0) {
		perror("bind");
		return -1;
	}

	listen(sockfd, 20);

	while (1) {
		addrlen = sizeof(client_addr);
		clientfd = accept(sockfd, (struct sockaddr*)&client_addr, &addrlen);

		receiver = recv(clientfd, buffer, MAXBUF, 0);
		printf("received kbag : %s\n", buffer);
	
		buffer[strlen(buffer) - 1] = '\0';
		key = kbag_main(buffer);

		send(clientfd, key, 96, 0);

		free(key);
		close(clientfd);
	}

	close(sockfd);
	return 0;
}

