#include "api_robot2.h"/*API control*/

void runforrest(void);
void runforrestrun(void);

void _start(void){
	set_time(1);
	add_alarm(runforrest,30);
	add_alarm(runforrestrun,31);
	while(1){}
}

void runforrest(void){
	set_motor_speed(0,20);
	unsigned int i;
	for(i = 0; i < 5000000; i++){}
}
void runforrestrun(void){
	set_motor_speed(1,25);
}
