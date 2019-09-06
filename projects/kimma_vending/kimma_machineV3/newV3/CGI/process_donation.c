#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/tcp.h>

#define TCP_SERVER_HOST "127.0.0.1"
#define TCP_SERVER_PORT 31421

int establish_tcp_connection(char *host, unsigned short int port);

/*
possible status:
    0 - success

    1 - query string not present
    20 - argument x is not present
    21 - argument y is not present
    4 - cannot establish link to daemon
    5 - cannot resolve hostname
    6 - communication link failure

*/

int main(int argc, char **argv)
{
    int  posX;
    int  posY;
    char  *x;
    char  *y;
    char  *query_string;
    int    daemon_link;
    int    packet_size;
    char   packet[64];
    int    result;

    setvbuf(stdout, NULL, _IONBF, 0);

    printf("Access-Control-Allow-Origin: *\r\n");
    printf("Content-Type: text/plain;charset=utf-8\r\n\r\n");

    query_string = getenv("QUERY_STRING");
    if(NULL == query_string || strlen(query_string)==0)
    {
        printf("status:1\n");

        return 1;
    }


    // ?x=20

    x = strcasestr(query_string, "x=");
    if(x)
    {
        posX = atoi(x+2);
    } else {
        printf("status:20\n");

        return 1;
    }



    y = strcasestr(query_string, "y=");
    if(y)
    {
        posY = atoi(y+2);
    } else {
        printf("status:21\n");

        return 1;
    }


    daemon_link = establish_tcp_connection(TCP_SERVER_HOST, TCP_SERVER_PORT);

    if(0 > daemon_link)
    {
        printf("status:4\n");

        return 1;
    }

    packet_size = sprintf(packet, "VEND,%u,%u\n", posX , posY);

    result = send(daemon_link, packet, packet_size, 0);

    if(-1 == result)
    {
        printf("status:5\n");

        shutdown(daemon_link, SHUT_RDWR);
        close(daemon_link);

        return 1;
    }

    memset(packet, 0, sizeof(packet));

    result = recv(daemon_link, packet, sizeof(packet), 0);

    if(-1 == result)
    {
        printf("status:6\n");

        shutdown(daemon_link, SHUT_RDWR);
        close(daemon_link);

        return 1;
    }

    printf("status:0\n");
    printf("message:");
    write(1, packet, result);

    shutdown(daemon_link, SHUT_RDWR);
    close(daemon_link);

    return 0;
}

int establish_tcp_connection(char *host, unsigned short int port)
{
    int                 result;
    int                 value;
    int                 sock;
    struct hostent     *hent;
    struct sockaddr_in  addr;
    struct timeval      tv;

    hent = gethostbyname(host);

    if(hent == NULL)
    {
        return -1;
    }

    memset(&addr, 0, sizeof(addr));

    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = ((struct in_addr **)hent->h_addr_list)[0]->s_addr;
    addr.sin_port = htons(port);

    sock = socket(AF_INET, SOCK_STREAM, 0);

    if(0 > sock)
    {
        return -2;
    }

    memset(&tv, 0, sizeof(struct timeval));
    
    tv.tv_sec = 60;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&tv, sizeof(struct timeval));

    value = 1;
    setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, (char *)&value, sizeof(int));

    value = 5;
    setsockopt(sock, SOL_SOCKET, TCP_KEEPCNT, (char *)&value, sizeof(int));

    value = 10;
    setsockopt(sock, SOL_SOCKET, TCP_KEEPIDLE, (char *)&value, sizeof(int));
    
    value = 30;
    setsockopt(sock, SOL_SOCKET, TCP_KEEPINTVL, (char *)&value, sizeof(int));

    result = connect(sock, (struct sockaddr *)&addr, sizeof(addr));

    if(-1 == result)
    {
        return -3;
    }

    return sock;
}
