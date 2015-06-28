#include "api_robot2.h"

void delay();
void para();
void anda();
void gira_direita();
void gira_esquerda();

int i = 0;

void _start(void) {
	unsigned int actual_time = 0;
	unsigned int speed = 0;
	actual_time = get_time();
	set_alarm(&anda, actual_time + 2);
	set_alarm(&para, actual_time + 4);
	set_alarm(&gira_direita, actual_time + 6);
	set_alarm(&para, actual_time + 8);
	set_alarm(&anda, actual_time + 10);
	while(1);
}

void para(){
	set_motors_speed(0, 0);
}

void anda(){
	set_motors_speed(15, 15);
}

void gira_direita(){
	set_motors_speed(10, 0);
}

void gira_esquerda(){
	set_motors_speed(0, 10);
}

/* Spend some time doing nothing. */
void delay() {
  int i;
  /* Not the best way to delay */
  for(i = 0; i < 900; i++ ){
  }
}