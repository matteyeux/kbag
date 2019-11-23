#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <include/kbag.h>
#include <include/server.h>

void usage(void)
{
	puts("usage: ./kbag <server> | [kbag] - kbag must be 96 hex characters");
}

int main(int argc, char **argv)
{
	char *decrypted = NULL;

	if (argc != 2 ) {
		usage();
		return -1;
	}

	if (!strcmp(argv[1], "server")) {
		server();
	} else if (strlen(argv[1]) == 96) {
		decrypted = kbag_main(argv[1]);
		if (decrypted == NULL) {
			printf("could not decrypt kbag\n");
		} else {
			printf("%s\n", decrypted);
			free(decrypted);
		}
	} else {
		usage();
		return -2;
	}

	return 0;
}
