Camada SOUL:

- Configurar GPIO (Entradas e Saĩdas):
  .set REG_DR,                0x53F84000     @Data Register
  .set REG_GDIR,              0x53F84004     @Direction Register
  .set REG_PSR,               0x53F84008     @Pad status register - apenas para leitura

- Configurar o TZIC
  .set TZIC_BASE,             0x0FFFC000
  .set TZIC_INTCTRL,          0x0
  .set TZIC_INTSEC1,          0x84 
  .set TZIC_ENSET1,           0x104
  .set TZIC_PRIOMASK,         0xC
  .set TZIC_PRIORITY9,        0x424

- Configurar GPT (Com tempo razoável)
  .set GPT_CR,             0x53FA0000
  .set GPT_PR,             0x53FA0004
  .set GPT_SR,             0x53FA0008
  .set GPT_IR,             0x53FA000C
  .set GPT_OCR1,           0x53FA0010
  
Mudar para nĩvel Usuário
Chamar código de controle
