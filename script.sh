#!/bin/bash

# Este script se encarga de consultar los datos de las instancias en ejecución y de realizar una simulación de ataque inyectando tráfico HTTP
# a la IP pública de una instancia, haciendo uso del SDK de Google Cloud y de la herramienta ApacheBench:


#Esta función realiza una consulta a GCP para obtener los datos de las instancias:
function obtenerDatos() {
	echo ""
	echo "Obteniendo datos para la comprobación de instancias, espere unos segundos..."
	echo ""
	#Se obtiene el nombre del grupo de autoescalado:
	nombre_grupo=$(gcloud compute instance-groups managed list | cut -d\  -f7)
	echo "El nombre del grupo de autoescalado es: "$nombre_grupo
	#Se obtiene el nombre de la región correspondiente al grupo de autoescalado:
	region_grupo=$(gcloud compute instance-groups managed list | cut -d\  -f3)
	echo "La región del grupo de autoescalado es: "$region_grupo
	#Obtiene el nombre de la instancia base en ejecución (datos en bruto):
	nombre_instancia_base=$(gcloud compute instance-groups managed list-instances $nombre_grupo --region=$(echo $region_grupo))
	#Obtiene el nombre de la zona correspondiente a la región de la instancia base en ejecución:
	zona_instancia_base=$(echo $nombre_instancia_base | cut -d\  -f10)
	echo "La zona de la instancia base es: "$zona_instancia_base
	#obtiene el nombre de la instancia base en ejecución:
	nombre_instancia_base=$(echo $nombre_instancia_base | cut -d\  -f9)
	echo "El nombre de la instancia base es: "$nombre_instancia_base
	#Obtiene la dirección IP pública efímera correspondiente a la instancia base, y que servirá para la simulación del ataque:
	ip_publica_instancia_base=$(gcloud compute instances describe $nombre_instancia_base --zone=$zona_instancia_base | grep natIP | cut -d\: -f2)
	echo "La dirección IP pública de la instancia base a la que atacar es:"$ip_publica_instancia_base
	echo "Estos son los datos obtenidos para las instancias del grupo de autoescalado que están en ejecución:"
	echo ""
	#Obtiene los datos de todas las instancias levantadas en el grupo de autoescalado en un momento dado:
	gcloud compute instances list | grep "grupo"
}

#Esta función comprueba el número de instancias levantadas y realiza una prueba ICMP de conectividad a las direcciónes IP internas de cada instancia:
function comprobar() {
	echo ""
	echo "Comprobando el número de instancias levantadas..."
	#Se obtiene el número de instancias levantadas en el grupo de autoescalado:
	cantidad_instancias=$(gcloud compute instance-groups list | cut -d " " -f15)
	#Se define una variable cuyo valor corresponde al rango de IPs internas de la región Europe/West3 (Francfurt):
	rango_ip_region=10.156.
	#Se guarda en un array las direcciones IP internas de las instancias que están levantadas y que será usado para realizar pruebas ICMP:
	array_ips=($(gcloud compute instances list | grep "grupo" | grep -o $rango_ip_region.......))
	echo "En este momento hay"$cantidad_instancias" instancias en ejecución en el grupo de autoescalado."
	echo ""
	echo "Estas son las direcciones IP internas que están respondiendo en este momento a ping:"
	#Se recorre el array de IPs internas para realizar pruebas de ICMP:
	for ((i=0; i<${#array_ips[@]}; i++)); do
	  direccion_ip_interna=${array_ips[$i]};
	  #Se realiza prueba ICMP de conectividad a la IP interna de una instancia dada:
	  ping -c 1 -W 1 $direccion_ip_interna >/dev/null && echo $direccion_ip_interna "-> is alive";
	done
	echo ""
}

# Esta función realiza la simulación de un ataque HTTP a la IP pública de la instancia base en ejecución del grupo de autoescalado.
# Para ello se hace uso de la herramienta ApacheBench que se encargará de generar una carga de tráfico de red al servidor Apache, solicitando
# una sucesión rápida de peticiones del mismo fichero (en este ejemplo el fichero es /index.html) para poder saturar la CPU del servidor y que
# de esta forma se puedan levantar el resto de instancias del grupo de autoescalado:
function ataque() {
        echo ""
        echo "Realizando ataque, espere unos segundos...";
        # Se define en una variable el comando a ejecutar para realizar el ataque.
        # El parámetro -n corresponde al número de solicitudes a realizar.
        # El parámetro -c corresponde a la concurrencia, es decir, el número de solicitudes múltiples para realizar a la vez.
        # El parámetro -s corresponde al número máximo de segundos de espera antes de un timeout del socket.
	comando="ab -n 50000 -c 1000 -s 50 http://"
	ip_publica=$(echo ${ip_publica_instancia_base})
        ataque=${comando}${ip_publica}/
	echo ""
	#Se ejecuta la variable que contiene el comando del ataque concatenado con la IP pública:
	$ataque
	echo ""
      	echo "Se ha realizado con exito el ataque a la instancia base del grupo de autoescalado";
	echo ""
	echo "Ejecute de nuevo el script pasandole el argumento comprobar para obtener las instancias levantadas."
	echo "Ejemplo: bash script.sh comprobar"  
	echo ""
	echo "Esperando 20 segundos a que levanten las instancias de autoescalado..."
	#Se define el número de segundo a esperar mientras se van levantando las instancias del grupo de autoescalado tras el ataque:
	sleep 20
	#Se llama a la función que comprueba el número de instancias en ejecución:
	comprobar
}


# Se define la sentencia de control que se usará para la utilización del script, en función del argumento que se le pase y que llamará
# a las funciones que correspondan según el argumento:
if [ -z $1 ]; then
  echo ""
  echo "No se ha ejecutado el script porque no se le ha pasado el argumento requerido..."  
  echo ""
  echo "Argumento comprobar --> Para comprobar las instancias en ejecución."
  echo "Argumento ataque --> Para realizar el ataque a una instancia a través de la IP pública."
  echo "Argumento datos --> Para obtener únicamente los datos del grupo de instancias."
  echo ""
elif [ $1 == comprobar ]; then
  obtenerDatos
  comprobar
elif [ $1 == ataque ]; then
  obtenerDatos
  ataque
elif [ $1 == datos ]; then
  obtenerDatos
fi


exit 0
