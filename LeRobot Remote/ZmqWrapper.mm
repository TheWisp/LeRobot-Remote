//
//  ZmqWrapper.m
//  LeRobot Remote
//
//  Created by Fei Teng on 26/05/2025.
//

#import <Foundation/Foundation.h>
#import "zmq.h"
#import <errno.h>
#import "LeRobot Remote-Bridging-Header.h"

void *cmd_socket = NULL;
void *video_socket = NULL;

void init_zmq(const char* remote_ip, const char* cmd_port, const char* video_port) {
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
    
    video_socket = zmq_socket(context, ZMQ_PULL);
    if (zmq_setsockopt(
                       video_socket,
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
    
    if (zmq_connect(cmd_socket, cmd_conn_str) != 0) {
        printf("Failed to connect to %s, errno = %s\n", cmd_conn_str, strerror(errno));
        zmq_close(cmd_socket);
        zmq_close(video_socket);
        zmq_ctx_destroy(context);
        return;
    }
    
    char video_conn_str[256];
    snprintf(video_conn_str, sizeof(cmd_conn_str), "tcp://%s:%s",
             remote_ip, video_port);
    
    if (zmq_connect(video_socket, video_conn_str) != 0) {
        printf("Failed to connect to %s, errno = %s\n", video_conn_str, strerror(errno));
        zmq_close(cmd_socket);
        zmq_close(video_socket);
        zmq_ctx_destroy(context);
        return;
    }
    printf("zmq connected to %s successfully!\n", cmd_conn_str);
}

void send_packet(const char* msg) {
    if (!cmd_socket) {
        printf("zmq is not initialized!\n");
        return;
    }
    
    int rc = zmq_send(cmd_socket, msg, strlen(msg), 0);
    if (rc == -1) {
        printf("Failed to send: %s, errno = %s\n", msg, strerror(errno));
        return;
    } else {
        //printf("zmq message sent: %s, total byte = %d\n", msg, rc);
    }
}

