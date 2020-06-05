echo -off
echo " "
echo Agora vamos carregar o Linux na memória. Isto pode demorar um tempo. Aguarde um pouco por favor ...
linux.efi initrd=initrd console=ttyS1,115200
