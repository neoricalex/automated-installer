echo -off
echo " "
echo Agora vamos carregar o Linux na RAM. Isto pode demorar. Aguarde um pouco por favor ...
linux.efi initrd=initrd console=ttyS1,115200
