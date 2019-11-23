/*
 
 compile with (assuming IOKit headers have been added to your iPhoneOS SDK):
 
 cat "$(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks/IOKit.framework/IOKit.tbd" | sed 's/x86_64/arm64/g' > IOKit.tbd
 xcrun clang kbag.m -o kbag -arch arm64 -framework Foundation -isysroot "$(xcrun --sdk iphoneos --show-sdk-path)" IOKit.tbd
 
 */

#include <IOKit/IOKitLib.h>

kern_return_t convert_kbag_string(char* str, uint8_t* buf, size_t size)
{
	printf("%lu : %lu\n",strlen(str), size*2);

	if (strlen(str) != size*2) {
		puts("invalid str passed");
		return -1;
	}
	char convbuf[5];
	char* convpt = 0;
	strcpy(convbuf, "0x00");
	for (int i=0; i<size; i++) {
		convbuf[2] = str[i*2];
		convbuf[3] = str[i*2+1];
		convpt = 0;
		buf[i] = (uint8_t)strtoul(convbuf, &convpt, 16);
		if (convpt != &convbuf[4]) {
			return -1;
		}
	}
	return 0;
}

// void dump_kbag(char* pre, uint8_t* buf, size_t size)
// {
// 	printf("%s: ", pre);
// 	for (int i=0; i<0x30; i++) {
// 		printf("%02x\n", buf[i]);
// 	}
// 	puts("");
// }


char *dump_kbag(char* pre, uint8_t* buf, size_t size)
{
	char *ret = NULL;

	ret = malloc(sizeof(char) * 96);
	if (ret == NULL) {
		printf("could not allocate memory\n");
		return ret;
	}

	printf("%s: ", pre);
	for (int i=0; i<0x30; i++) {
		if (i == 0) {
			sprintf(ret, "%02x", buf[i]);
		} else
			sprintf(ret, "%s%02x", ret, buf[i]);

	}
	return (char *)ret;
}


io_connect_t aes_accel()
{
	io_iterator_t iterator;
	IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOAESAccelerator"), &iterator);
	io_service_t accel = IOIteratorNext(iterator);
	io_connect_t connect = 0;
	IOServiceOpen(accel, mach_task_self(), 0, &connect);
	if (!connect) {
		puts("couldn't connect to IOAESAccelerator! :(");
		return (io_connect_t)-1;
	}

	return connect;
}

struct request {
	unsigned char* addr_from;
	unsigned char* addr_to;
	uint32_t data_size;
	uint8_t x5[0x10];
	uint32_t w6;
	uint32_t unk; // appears to be key size
	char x7[0x20]; // reference to this is passed
	uint32_t keyid; // cmp with 0x839, later 0x3e8 -> key ID (0x3e8 is GID)
	uint32_t some_sort_of_size; // cmp with structure input size, seems like this being 0 is just fine
	uint32_t unk_; // probably just padding
};
_Static_assert (sizeof(struct request) == 0x58, "fail");


kern_return_t decrypt_kbag(io_connect_t accel, uint8_t* buffer, size_t size)
{
	if (size != 0x30) return -1;
	struct request req, reqOut;
	bzero(&req,sizeof(req));
	req.addr_from = buffer;
	req.addr_to = buffer;
	req.data_size = 0x30;
	req.keyid = 0x3e8;
	req.w6 = 1;
	req.unk = 256;
	size_t reqOutSize = 0x58;
	kern_return_t err = IOConnectCallStructMethod(accel, 1, (void*)&req, 0x58, (void*)&reqOut, &reqOutSize);
	return err == 0 ? 0 : -1;
}

char *kbag_main(char *kbag)
{
	char *encrypted_kbag = NULL;
	char *decrypted_kbag = NULL;

	io_connect_t accel = aes_accel();
	if (accel == -1) return NULL;

	uint8_t kbagbuf[0x30];
	if (convert_kbag_string(kbag, kbagbuf, 0x30) != 0) return NULL;

	encrypted_kbag = dump_kbag("encrypted kbag", kbagbuf, 0x30);
	if (encrypted_kbag == NULL) {
		return NULL;
	}

	printf("%s\n", encrypted_kbag);
	free(encrypted_kbag);

	kern_return_t err = decrypt_kbag(accel, kbagbuf, 0x30);

	if (err != 0) {
		puts("decryption failed! :(");
		puts("IOAESAccelerator must be patched to allow for key 0x3e8 use.");
		puts("It's possible this patch is missing in your kernel. Please look at this tool's source code for additional information on how to patch your kernel for this.");
		/*

		 In IOCryptoAcceleratorFamily do a immediate search for 0x3E8.
		 One particular routine will have two uses, one is a SUB and one is a CMP.
		 The SUB looks something like this:
		 
			09 A1 0F 51                 SUB             W9, W8, #0x3E8
			3F 09 00 71                 CMP             W9, #2
			83 0E 00 54                 B.CC            failure_case     <--- NOP out
		 
		 
		 Additionally, this assumes iBoot is patched as to leave GID key usable even after loading the kernelcache.
		 In order to accomplish this, platform_disable_keys must be patched.
		 To locate this function, at least on A12, search immediate for 0x23D2D0000. Only two matches are present.
		 One of the two functions will end up using that immediate as an address and perform a write to it. This is "platform_disable_keys".
		 
		 Patch the very first instruction of this function into a RET instruction in order to prevent GID from being disabled.
		 
		 
		 AppleS8000AES seems to also disable GID for some reason. You can patch the kernel (must be done before early init!) to disable this.
		 
		 A binary search for the following opcode in AppleS8000AES turns up two results:

			3F A0 0F 71                 CMP             W1, #0x3E8
		 
		 The two routines are similar, but one will return a value which is LDR'd from somewhere, while the other returns an immediate constant.
		 The routine returning the immediate constant only has one xref.
		 The xref is from a function that does very little (only a STR) other than calling the function we xref'd from.
		 
		 Patch the first instruction of this function into a RET as to prevent it from running and the GID key will stay enabled all the time.
		 
		 */
		
		return NULL;
	}

	decrypted_kbag = dump_kbag("decrypted kbag", kbagbuf, 0x30);
	IOServiceClose(accel);

	return decrypted_kbag;
}



