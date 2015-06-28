#include "api_robot2.h"/*API control*/

void runforrest(void);
void runforrestrun(void);

void _start(void){
	set_time(1);
	add_alarm(runforrest,30);
	add_alarm(runforrestrun,30);
	while(1){}
}

void runforrest(void){
	set_motors_speed(20,20);
}
void runforrestrun(void){
	set_motors_speed(40,40);
}
