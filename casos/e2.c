#include "api_robot2.h"/*API control*/



void _start(void){
	set_motor_speed(30,30);
		       /* Para verificar o valor retornado, será utilizado o GDB */
	while(1){}
}

