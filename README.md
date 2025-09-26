DESCRIPCION DEL CONTRATO:
KipuBank es un contrato inteligente que permite a los usuarios depositar y retirar ETH en bóvedas personales con reglas de seguridad:

-El banco tiene un límite global (bankCap) de fondos.

-Cada retiro está limitado por un monto máximo por transacción (perTxWithdrawalLimit).

-Los depósitos y retiros actualizan saldos, llevan contadores de operaciones y emiten eventos.

-Incluye validaciones y errores personalizados, un reentrancy guard y transferencias seguras de ETH.

-Proporciona funciones view para consultar saldos individuales y el espacio restante del banco.

INSTRUCCIONES DE DEPLOYMENT (para desplegar el contrato en Sepolia):

- Abrir Remix IDE, creando un archivo en la carpeta "contracts", llamado "KipuBank.sol" (.sol es la extension de Solidity), y pegar el contrato.

- Compilar con Solidity 0.8.20

- En Deploy & Run Transactions:

   - En el campo Evironment: seleccionar Injected Provider (Metmask) y conectar la billetera
 
   - En el campo Contract: verificar que diga el nombre del contrato con el que nombramos al   archivo "KipuBank.sol"
 
   - Ingresar los parámetros del constructor en los campos del panel Deploy (bankCap y perTxWithdrawalLimit), es importante que los montos se expresen en Wei.

- Click en Deploy, confirmando la transacción en Metamask.

- Copiar la dirección del contrato y buscar en Sepolia Etherscan

- En la pestaña Contract, hacer click en Verify and Publish y seguir los pasos indicados.

CÓMO INTERACTUAR CON EL CONTRATO:

Se puede interactuar con el código directamente desde Etherscan. En la pestaña Write Contract, conectar con MetaMask. Se puede llamar a deposit() enviando ETH en el campo “Value” o ejecutar withdraw(amount) para retirar, siempre respetando los limites de saldo y el límite por transacción. En la pestaña Read Contract se tiene acceso a funciones de consulta como getMyVault() para revisar tu saldo, getVaultBalance(address) para revisar el de otra cuenta y getRemainingBankCap() para saber cuánto espacio queda en el banco. También, si se prefiere, se puede interactuar desde Remix conectando la interfaz al contrato ya desplegado en Sepolia.
