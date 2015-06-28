#include "api_robot2.h"/*API control*/



void _start(void){
	set_motors_speed(30,100);
		       /* Para verificar o valor retornado, será utilizado o GDB */
	while(1){}
}

