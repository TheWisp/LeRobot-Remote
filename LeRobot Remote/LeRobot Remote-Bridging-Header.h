//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#ifdef __cplusplus
extern "C" {
#endif

void init_zmq();
void send_packet(const char* msg);

#ifdef __cplusplus
}
#endif
