
#!/bin/bash

# Hacemos 200 peticiones concurrentes para rebasar el límite de 150 (50 hilos + 100 en cola)
TOTAL_PETICIONES=500
URL="http://localhost:8080/api/v1/test-rest/api/probar-ruta"

echo "🔥 Iniciando ataque de saturación con $TOTAL_PETICIONES peticiones concurrentes..."

for ((i=1; i<=TOTAL_PETICIONES; i++)); do
    # curl en modo silencioso (-s), con un timeout máximo de 40s (-m 40) 
    # El símbolo '&' al final envía el proceso a segundo plano, lanzando todos al mismo tiempo
    curl -s -m 40 $URL > /dev/null &
done

echo "⏳ Todas las peticiones fueron disparadas. Esperando respuestas (o fallos)..."
wait
echo "✅ Ataque finalizado."