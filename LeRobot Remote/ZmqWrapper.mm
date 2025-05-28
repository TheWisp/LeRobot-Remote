//
//  ZmqWrapper.m
//  LeRobot Remote
//
//  Created by Fei Teng on 26/05/2025.
//

#import <Foundation/Foundation.h>
#import "zmq.h"
#import "LeRobot Remote-Bridging-Header.h"

void *cmd_socket = NULL;

void init_zmq() {
    const char *remote_ip = "192.168.1.137";
    const char *cmd_port = "5555";
    
    
    void *context = zmq_ctx_new();
    if (!context) {
        printf("Failed to create zmq context\n");
        return;
    }
    
    cmd_socket = zmq_socket(context, ZMQ_PUSH);
    if (!cmd_socket) {
        printf("Failed to create command socket\n");
        zmq_ctx_destroy(context);
        return;
    }
    
    int conflate = 1;
    if (zmq_setsockopt(
                       cmd_socket,
                       ZMQ_CONFLATE,           // Keep only the last message
                       &conflate,
                       sizeof(conflate)
                       ) != 0) {
                           printf("Failed to set conflate flag\n");
                           zmq_close(cmd_socket);
                           zmq_ctx_destroy(context);
                           return;
                       }
    
    // Build connection string and connect
    char cmd_conn_str[256];
    snprintf(cmd_conn_str, sizeof(cmd_conn_str), "tcp://%s:%s",
             remote_ip, cmd_port);
    /*
    if (zmq_connect(cmd_socket, cmd_conn_str) != 0) {
        printf("Failed to connect to %s\n", cmd_conn_str);
        zmq_close(cmd_socket);
        zmq_ctx_destroy(context);
        return;
    }
     */
    zmq_bind(cmd_socket, cmd_conn_str);
    printf("zmq connected to %s successfully!\n", cmd_conn_str);
}

void send_packet(const char* msg) {
    if (!cmd_socket) {
        printf("zmq is not initialized!\n");
        return;
    }
    
    zmq_send(cmd_socket, msg, strlen(msg), 0);
    printf("zmq message sent: %s\n", msg);
}
