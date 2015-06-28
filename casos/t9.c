#include "api_robot2.h"/*API control*/

void runforrest(void);

void _start(void){
	set_time(1);
	add_alarm(runforrest,30);
	while(1){}
}

void runforrest(void){
	set_motors_speed(20,20);
}
