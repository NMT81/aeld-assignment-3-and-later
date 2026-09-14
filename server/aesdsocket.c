#include <stdio.h>
#include <stdbool.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/sendfile.h>
#include <sys/stat.h>
#include <netdb.h>
#include <fcntl.h>
#include <unistd.h>
#include <syslog.h>
#include <string.h>

#define BUFFER_SIZE 1024
#define TMP_DATA "/var/tmp/aesdsocketdata"

volatile bool signal_captured = false;

void handle_signal(int signal_num) {

    if ((signal_num == SIGINT) || (signal_num == SIGTERM))
    {
        signal_captured = true;
    }
}

int main (int argc, char *argv[])
{
    struct sigaction sa;
    int server_fd, client_fd, tmp_fd, bytes_received;
    struct addrinfo hints, *res, *p;
    struct sockaddr_storage client_addr;
    socklen_t addr_size;
    char buf[BUFFER_SIZE];
    char ip[INET6_ADDRSTRLEN];
    int tmp_data_size;
    int yes = 1;
    pid_t pid;

    // Setup stream socket binding on port 9000
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;

    if (getaddrinfo(NULL, "9000", &hints, &res) != 0) {
        printf("fail getaddrinfo\n\r");
        return -1;
    }
    for (p = res; p != NULL; p = p->ai_next) {
        server_fd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (server_fd == -1) {
            continue;
        }

        setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int));

        if (bind(server_fd, p->ai_addr, p->ai_addrlen) == 0) {
            break;
        }
        close(server_fd);
    }
    freeaddrinfo(res);
    if (p == NULL) {
        printf("Fail setting socket\n\r");
        return -1;
    }

    // check argument, create deamon
    if ((argc > 1) && (strcmp(argv[1],"-d") == 0)){
        pid = fork();
        if (pid > 0){           //parent process
            return 0;
        } else if (pid == 0){   //child process
            setsid();           // start new session
            umask(0);           // Reset file permissions mask
            close(STDIN_FILENO);// detech session controls 
            close(STDOUT_FILENO);
            close(STDERR_FILENO);
        }
    }

    // Configure the sigaction structure
    sa.sa_handler = handle_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;    // No special flags

    // Register handler for SIGINT
    if (sigaction(SIGINT, &sa, NULL) == -1) {
        return 1;
    }

    // Register handler for SIGTERM
    if (sigaction(SIGTERM, &sa, NULL) == -1) {
        return 1;
    }

    if (listen(server_fd, 5) == -1) {
        close(server_fd);
        return -1;
    }

    // Setup logging
    openlog(argv[0], LOG_PID, LOG_USER);

    tmp_fd = open(TMP_DATA, O_RDWR | O_CREAT | O_APPEND, 0644);
    tmp_data_size = 0;

    // loop accept, receive, send
    while(1)
    {
        addr_size = sizeof(client_addr);
        client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &addr_size);
        if (client_fd == -1) {
            break;
        }
        getnameinfo((struct sockaddr *)&client_addr, addr_size,
                      ip, sizeof(ip), 
                      NULL, 0,
                      NI_NUMERICHOST);
        syslog(LOG_DEBUG, "Accepted connection from %s", ip);        

        while(1)
        {
            //memset(buf, 0, BUFFER_SIZE);
            bytes_received = recv(client_fd, buf, BUFFER_SIZE - 1, 0);
            if (bytes_received == -1) {         // error or signal arrived
                break;
            } else {
                write(tmp_fd, buf, bytes_received);
                tmp_data_size += bytes_received;
                if (buf[bytes_received - 1] == '\n')
                {
                    off_t offset = 0;
                    sendfile(client_fd, tmp_fd, &offset, tmp_data_size);
                    break;
                }
            }
        }
        close(client_fd);
        
        if (signal_captured){
            break;
        } else {
            syslog(LOG_DEBUG, "Closed connection from %s", ip);
        }
    }
    if (signal_captured){
        syslog(LOG_DEBUG, "Caught signal, exiting");
    }
    close(server_fd);
    closelog();
    close(tmp_fd);
    remove(TMP_DATA);

    return 0;
}
