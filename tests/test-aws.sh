#!/bin/bash

# =============================================================================
# Pruebas de la aplicación Circuit Breaker en AWS ECS Fargate
# =============================================================================
#
# Prerequisitos:
#   - AWS CLI configurado con credenciales válidas
#   - El stack de CloudFormation desplegado
#   - jq instalado (sudo apt install jq / brew install jq)
#   - Session Manager plugin instalado (para ECS Exec)
#     https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
#
# Uso:
#   chmod +x tests/test-aws.sh
#   bash tests/test-aws.sh <ALB_DNS>
#
# Ejemplo:
#   bash tests/test-aws.sh circuit-breaker-demo-alb-123456.us-east-1.elb.amazonaws.com
# =============================================================================

set -e

# --- Configuración ---
ALB_DNS="${1:-}"
CLUSTER_NAME="${2:-circuit-breaker-demo-cluster}"
TOTAL_PETICIONES=500
TIMEOUT=40

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Sin color

if [ -z "$ALB_DNS" ]; then
  echo -e "${RED}Error: Debes proporcionar el DNS del ALB como primer argumento.${NC}"
  echo ""
  echo "Uso: bash tests/test-aws.sh <ALB_DNS> [CLUSTER_NAME]"
  echo ""
  echo "Puedes obtener el DNS del ALB con:"
  echo "  aws cloudformation describe-stacks --stack-name circuit-breaker-demo \\"
  echo "    --query \"Stacks[0].Outputs[?OutputKey=='ALBURL'].OutputValue\" --output text"
  exit 1
fi

BASE_URL="http://${ALB_DNS}"

# =============================================================================
# Funciones auxiliares
# =============================================================================

print_header() {
  echo ""
  echo -e "${CYAN}============================================================${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}============================================================${NC}"
  echo ""
}

check_response() {
  local description="$1"
  local url="$2"
  local expected_code="${3:-200}"

  local http_code
  local body
  body=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "$url" 2>/dev/null || echo "000")

  if [ "$body" == "$expected_code" ]; then
    echo -e "  ${GREEN}✅ $description — HTTP $body${NC}"
    return 0
  else
    echo -e "  ${RED}❌ $description — HTTP $body (esperado: $expected_code)${NC}"
    return 1
  fi
}

get_task_id() {
  aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name circuit-breaker-demo-app-service \
    --desired-status RUNNING \
    --query "taskArns[0]" \
    --output text 2>/dev/null | awk -F'/' '{print $NF}'
}

# =============================================================================
# PRUEBA 1: Health Check — Verificar que la app está viva
# =============================================================================

print_header "PRUEBA 1: Health Check (ping)"

echo "  Endpoint: ${BASE_URL}/api/v1/test-rest/ping"
echo ""

PING_RESPONSE=$(curl -s -m 10 "${BASE_URL}/api/v1/test-rest/ping" 2>/dev/null || echo "ERROR")

if [[ "$PING_RESPONSE" == *"Prueba inicial"* ]]; then
  echo -e "  ${GREEN}✅ La app está respondiendo correctamente${NC}"
  echo -e "  Respuesta: ${PING_RESPONSE}"
else
  echo -e "  ${RED}❌ La app no responde. Verifica que el stack esté desplegado y el servicio healthy.${NC}"
  echo -e "  Respuesta: ${PING_RESPONSE}"
  echo ""
  echo "  Comandos de diagnóstico:"
  echo "    aws ecs describe-services --cluster $CLUSTER_NAME --services circuit-breaker-demo-app-service"
  echo "    aws logs tail /ecs/circuit-breaker-demo/app --since 10m"
  exit 1
fi

# =============================================================================
# PRUEBA 2: Circuit Breaker — Llamada normal (sin latencia)
# =============================================================================

print_header "PRUEBA 2: Circuit Breaker — Llamada normal (sin latencia)"

echo "  Endpoint: ${BASE_URL}/api/v1/test-rest/api/probar-ruta"
echo ""

CB_RESPONSE=$(curl -s -m 15 "${BASE_URL}/api/v1/test-rest/api/probar-ruta" 2>/dev/null || echo "ERROR_TIMEOUT")

if [[ "$CB_RESPONSE" == *"ERROR_TIMEOUT"* ]]; then
  echo -e "  ${RED}❌ Timeout al llamar al endpoint. Posible problema con Toxiproxy o httpbin.${NC}"
elif [[ "$CB_RESPONSE" == *"no está disponible"* ]]; then
  echo -e "  ${YELLOW}⚠️  El Circuit Breaker está ABIERTO (fallback activo). Puede que ya haya fallos previos.${NC}"
  echo -e "  Respuesta: ${CB_RESPONSE}"
else
  echo -e "  ${GREEN}✅ Respuesta exitosa de la API externa (vía Toxiproxy → httpbin)${NC}"
  echo -e "  Respuesta (primeros 200 chars): ${CB_RESPONSE:0:200}"
fi

check_response "HTTP Status" "${BASE_URL}/api/v1/test-rest/api/probar-ruta"

# =============================================================================
# PRUEBA 3: Inyección de latencia vía ECS Exec
# =============================================================================

print_header "PRUEBA 3: Inyectar latencia con Toxiproxy (vía ECS Exec)"

TASK_ID=$(get_task_id)

if [ -z "$TASK_ID" ] || [ "$TASK_ID" == "None" ]; then
  echo -e "  ${RED}❌ No se encontró un task running en el cluster.${NC}"
  echo "  Verifica con: aws ecs list-tasks --cluster $CLUSTER_NAME"
  echo ""
  echo -e "  ${YELLOW}⚠️  Saltando pruebas de inyección de latencia.${NC}"
else
  echo "  Task ID: ${TASK_ID}"
  echo ""
  echo -e "  ${YELLOW}Nota: ECS Exec requiere que el task tenga habilitado 'enableExecuteCommand'.${NC}"
  echo -e "  ${YELLOW}Si falla, habilítalo actualizando el servicio ECS con --enable-execute-command.${NC}"
  echo ""
  echo "  Para inyectar latencia manualmente, ejecuta:"
  echo ""
  echo -e "  ${CYAN}aws ecs execute-command \\${NC}"
  echo -e "  ${CYAN}  --cluster $CLUSTER_NAME \\${NC}"
  echo -e "  ${CYAN}  --task $TASK_ID \\${NC}"
  echo -e "  ${CYAN}  --container toxiproxy \\${NC}"
  echo -e "  ${CYAN}  --interactive \\${NC}"
  echo -e "  ${CYAN}  --command \"/bin/sh\"${NC}"
  echo ""
  echo "  Ya dentro del contenedor:"
  echo ""
  echo -e "  ${CYAN}# Agregar latencia de 30 segundos${NC}"
  echo -e "  ${CYAN}curl -s -X POST http://localhost:8474/proxies/proxy_hacia_api_externo/toxics \\${NC}"
  echo -e "  ${CYAN}  -H 'Content-Type: application/json' \\${NC}"
  echo -e "  ${CYAN}  -d '{\"name\":\"latencia_extrema\",\"type\":\"latency\",\"stream\":\"downstream\",\"toxicity\":1.0,\"attributes\":{\"latency\":30000}}'${NC}"
  echo ""
  echo -e "  ${CYAN}# Eliminar la latencia${NC}"
  echo -e "  ${CYAN}curl -s -X DELETE http://localhost:8474/proxies/proxy_hacia_api_externo/toxics/latencia_extrema${NC}"
fi

# =============================================================================
# PRUEBA 4: Estrés — 500 peticiones concurrentes
# =============================================================================

print_header "PRUEBA 4: Prueba de estrés ($TOTAL_PETICIONES peticiones concurrentes)"

echo "  Endpoint: ${BASE_URL}/api/v1/test-rest/api/probar-ruta"
echo "  Timeout por petición: ${TIMEOUT}s"
echo ""

RESULTS_FILE=$(mktemp)

echo -e "  ${YELLOW}🔥 Disparando $TOTAL_PETICIONES peticiones...${NC}"

for ((i=1; i<=TOTAL_PETICIONES; i++)); do
  curl -s -o /dev/null -w "%{http_code}\n" -m $TIMEOUT \
    "${BASE_URL}/api/v1/test-rest/api/probar-ruta" >> "$RESULTS_FILE" 2>/dev/null &
done

echo -e "  ${YELLOW}⏳ Esperando respuestas...${NC}"
wait

# Contar resultados
TOTAL=$(wc -l < "$RESULTS_FILE")
OK=$(grep -c "200" "$RESULTS_FILE" 2>/dev/null || echo "0")
ERRORS=$(grep -cv "200" "$RESULTS_FILE" 2>/dev/null || echo "0")

echo ""
echo "  Resultados:"
echo -e "  ${GREEN}  ✅ Exitosas (200):  $OK${NC}"
echo -e "  ${RED}  ❌ Fallidas:        $ERRORS${NC}"
echo "     Total:            $TOTAL"
echo ""

# Desglose de códigos HTTP
echo "  Desglose por código HTTP:"
sort "$RESULTS_FILE" | uniq -c | sort -rn | while read count code; do
  echo "    HTTP $code → $count peticiones"
done

rm -f "$RESULTS_FILE"

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo -e "  ${YELLOW}ℹ️  Las peticiones fallidas pueden ser por:${NC}"
  echo "     - Circuit Breaker abierto (comportamiento esperado bajo estrés)"
  echo "     - Timeout del ALB o del contenedor"
  echo "     - OutOfMemoryError (revisar logs en CloudWatch)"
  echo ""
  echo "  Revisar logs:"
  echo "    aws logs tail /ecs/circuit-breaker-demo/app --since 5m --filter-pattern \"OutOfMemoryError\""
fi

# =============================================================================
# PRUEBA 5: Verificar que la app sigue viva después del estrés
# =============================================================================

print_header "PRUEBA 5: Health Check post-estrés"

echo "  Esperando 5 segundos para que la app se estabilice..."
sleep 5

PING_POST=$(curl -s -m 10 "${BASE_URL}/api/v1/test-rest/ping" 2>/dev/null || echo "ERROR")

if [[ "$PING_POST" == *"Prueba inicial"* ]]; then
  echo -e "  ${GREEN}✅ La app sigue respondiendo después de la prueba de estrés${NC}"
else
  echo -e "  ${RED}❌ La app NO responde después del estrés. Posible OOM o crash del contenedor.${NC}"
  echo ""
  echo "  Diagnóstico:"
  echo "    aws logs tail /ecs/circuit-breaker-demo/app --since 5m"
  echo "    aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks \$(aws ecs list-tasks --cluster $CLUSTER_NAME --query 'taskArns[0]' --output text)"
fi

# =============================================================================
# Resumen
# =============================================================================

print_header "RESUMEN"

echo "  ALB URL:     ${BASE_URL}"
echo "  Cluster:     ${CLUSTER_NAME}"
echo "  Peticiones:  ${TOTAL_PETICIONES}"
echo "  Exitosas:    ${OK}"
echo "  Fallidas:    ${ERRORS}"
echo ""
echo "  Logs útiles:"
echo "    aws logs tail /ecs/circuit-breaker-demo/app --since 15m"
echo "    aws logs tail /ecs/circuit-breaker-demo/toxiproxy --since 15m"
echo ""
echo -e "  ${CYAN}Pruebas finalizadas.${NC}"
echo ""
