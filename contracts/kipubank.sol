// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/**
	*@title Contrato kipubank
        *@notice Este es un contrato con fines educativos.
        *@author Paloma de Aza
        *@custom:security No usar en producción.
*/
contract kipubank {
 /* ------------------------------------------------------------------------
       ERRORS (custom errors - gas efficient and explícitos)
       ------------------------------------------------------------------------ */

    /// @notice Lanzado cuando el depósito es cero.
    error KipuBank_ZeroDeposit();

    /// @notice Lanzado cuando el depósito excede la capacidad del banco.
    /// @param attemptedAmount monto que intentó depositarse
    /// @param remainingCap espacio restante en el bankCap
    error KipuBank_ExceedsBankCap(uint256 attemptedAmount, uint256 remainingCap);

    /// @notice Lanzado cuando el retiro excede el saldo del usuario.
    /// @param requested monto solicitado
    /// @param available saldo disponible
    error KipuBank_InsufficientBalance(uint256 requested, uint256 available);

    /// @notice Lanzado cuando el retiro excede el límite por transacción.
    /// @param requested monto solicitado
    /// @param perTxLimit límite por transacción
    error KipuBank_ExceedsPerTxWithdrawalLimit(uint256 requested, uint256 perTxLimit);

    /// @notice Lanzado cuando la transferencia nativa falla.
    error KipuBank_TransferFailed();

    /// @notice Lanzado si se detecta reentrancy.
    error KipuBank_ReentrancyDetected();

    /* ------------------------------------------------------------------------
       IMMUTABLE / CONSTANTS
       ------------------------------------------------------------------------ */

    /// @notice Cap global del banco (máximo total de ETH que puede contener el contrato).
    uint256 public immutable bankCap;

    /// @notice Límite fijo por retiro por transacción (inmutable).
    uint256 public immutable perTxWithdrawalLimit;

    /* ------------------------------------------------------------------------
       STATE VARIABLES (almacenamiento)
       ------------------------------------------------------------------------ */

    /// @notice Saldo por usuario: dirección => wei
    mapping(address => uint256) private vaultBalances;

    /// @notice Número de depósitos realizados por cada usuario.
    mapping(address => uint256) public userDepositCount;

    /// @notice Número de retiros realizados por cada usuario.
    mapping(address => uint256) public userWithdrawCount;

    /// @notice Suma total actualmente depositada en el banco (suma de todos los vaultBalances).
    uint256 public totalBankBalance;

    /// @notice Contador global de depósitos exitosos.
    uint256 public totalDepositsCount;

    /// @notice Contador global de retiros exitosos.
    uint256 public totalWithdrawalsCount;

    /* ------------------------------------------------------------------------
       REENTRANCY GUARD
       ------------------------------------------------------------------------ */

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    /* ------------------------------------------------------------------------
       EVENTS
       ------------------------------------------------------------------------ */

    /**
     * @notice Emitido cuando un usuario deposita ETH en su bóveda.
     * @param who dirección del usuario que depositó
     * @param amount cantidad depositada (wei)
     * @param timestamp momento del depósito (block.timestamp)
     * @param userDepositIndex índice de depósito del usuario (1-based)
     */
    event Deposit(
        address indexed who,
        uint256 amount,
        uint256 timestamp,
        uint256 userDepositIndex
    );

    /**
     * @notice Emitido cuando un usuario retira ETH de su bóveda.
     * @param who dirección del usuario que retiró
     * @param amount cantidad retirada (wei)
     * @param timestamp momento del retiro (block.timestamp)
     * @param userWithdrawIndex índice de retiro del usuario (1-based)
     */
    event Withdrawal(
        address indexed who,
        uint256 amount,
        uint256 timestamp,
        uint256 userWithdrawIndex
    );

    /* ------------------------------------------------------------------------
       MODIFIERS
       ------------------------------------------------------------------------ */

    /**
     * @dev Reentrancy guard modifier.
     */
    modifier nonReentrant() {
        if (_status == _ENTERED) revert KipuBank_ReentrancyDetected();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Verifica que el amount sea mayor que cero.
     * @param amount cantidad a validar
     */
    modifier onlyNonZero(uint256 amount) {
        if (amount == 0) revert KipuBank_ZeroDeposit();
        _;
    }

    /* ------------------------------------------------------------------------
       CONSTRUCTOR
       ------------------------------------------------------------------------ */

    /**
     * @notice Crea KipuBank con un bankCap global y un límite por retiro por transacción.
     * @param _bankCap Límite global máximo que la bóveda del banco puede contener (wei).
     * @param _perTxWithdrawalLimit Límite máximo que un usuario puede retirar en una sola transacción (wei).
     */
    constructor(uint256 _bankCap, uint256 _perTxWithdrawalLimit) {
        require(_bankCap > 0, "bankCap must be > 0");
        require(_perTxWithdrawalLimit > 0, "perTxWithdrawalLimit must be > 0");
        require(
            _perTxWithdrawalLimit <= _bankCap,
            "perTxWithdrawalLimit must be <= bankCap"
        );

        bankCap = _bankCap;
        perTxWithdrawalLimit = _perTxWithdrawalLimit;

        // init reentrancy guard
        _status = _NOT_ENTERED;
    }

    /* ------------------------------------------------------------------------
       EXTERNAL / PUBLIC FUNCTIONS
       ------------------------------------------------------------------------ */

    /**
     * @notice Deposita ETH en la bóveda personal del remitente.
     * @dev Sigue checks-effects-interactions: valida espacio, actualiza estado, emite evento.
     *      Reverte con errores personalizados si falla la validación.
     *
     * Requirements:
     *  - msg.value debe ser > 0
     *  - totalBankBalance + msg.value <= bankCap
     */
    function deposit() external payable onlyNonZero(msg.value) {
        uint256 amount = msg.value;

        // checks: espacio restante en bankCap
        uint256 remaining = bankCap - totalBankBalance;
        if (amount > remaining) revert KipuBank_ExceedsBankCap(amount, remaining);

        // effects: actualizar saldos y contadores (antes de interacción)
        vaultBalances[msg.sender] += amount;
        totalBankBalance += amount;

        unchecked {
            // actualizaciones de contadores (sin overflow verificación explícita para gas)
            userDepositCount[msg.sender] += 1;
            totalDepositsCount += 1;
        }

        // interactions: no hay llamada externa aquí; sólo emitir evento
        emit Deposit(msg.sender, amount, block.timestamp, userDepositCount[msg.sender]);
    }

    /**
     * @notice Retira ETH desde la bóveda personal del remitente hasta el límite por transacción.
     * @param amount cantidad a retirar (wei)
     * @dev Sigue checks-effects-interactions: valida límites, actualiza estado, luego realiza la transferencia segura.
     */
    function withdraw(uint256 amount) external nonReentrant onlyNonZero(amount) {
        // checks
        if (amount > perTxWithdrawalLimit) {
            revert KipuBank_ExceedsPerTxWithdrawalLimit(amount, perTxWithdrawalLimit);
        }

        uint256 userBalance = vaultBalances[msg.sender];
        if (amount > userBalance) {
            revert KipuBank_InsufficientBalance(amount, userBalance);
        }

        // effects
        // resta antes de la interacción para prevenir reentrancy clásico
        vaultBalances[msg.sender] = userBalance - amount;
        totalBankBalance -= amount;

        unchecked {
            userWithdrawCount[msg.sender] += 1;
            totalWithdrawalsCount += 1;
        }

        // interactions: transferencia segura
        _safeTransferETH(payable(msg.sender), amount);

        emit Withdrawal(msg.sender, amount, block.timestamp, userWithdrawCount[msg.sender]);
    }

    /**
     * @notice Vista externa para obtener el saldo de la bóveda de una dirección.
     * @param who dirección a consultar
     * @return balance saldo en wei
     */
    function getVaultBalance(address who) external view returns (uint256 balance) {
        return vaultBalances[who];
    }

    /**
     * @notice Conveniencia: devuelve el saldo del remitente.
     * @return balance saldo del msg.sender en wei
     */
    function getMyVault() external view returns (uint256 balance) {
        return vaultBalances[msg.sender];
    }

    /**
     * @notice Consulta cuánto queda disponible para depositar antes de alcanzar bankCap.
     * @return remaining espacio restante (wei)
     */
    function getRemainingBankCap() external view returns (uint256 remaining) {
        return bankCap - totalBankBalance;
    }

    /* ------------------------------------------------------------------------
       PRIVATE / INTERNAL HELPERS
       ------------------------------------------------------------------------ */

    /**
     * @dev Función privada para realizar transferencias nativas de forma segura usando call.
     *      Reverte con KipuBank_TransferFailed si la transferencia falla.
     * @param recipient dirección destino (payable)
     * @param amount cantidad a enviar (wei)
     */
    function _safeTransferETH(address payable recipient, uint256 amount) private {
        // Usamos call para enviar ETH y evitar límites de gas que impone transfer/send.
        // No hay código después de la llamada que dependa del éxito, por eso revertimos si falla.
        (bool ok, ) = recipient.call{value: amount}("");
        if (!ok) revert KipuBank_TransferFailed();
    }

    /* ------------------------------------------------------------------------
       FALLBACK / RECEIVE
       ------------------------------------------------------------------------ */

    /**
     * @notice Receive evita depósitos accidentales a través de receive; obliga a usar deposit()
     * @dev Reverte con KipuBank_ZeroDeposit si msg.value == 0 o con KipuBank_ExceedsBankCap si excede.
     */
    receive() external payable {
        // Option 1: permitir depositar vía receive redirigiendo a deposit() (más amigable)
        // pero para claridad y para emitir evento uniformemente preferimos obligar al uso de deposit().
        // Para ser útiles, si queremos aceptar receive, haríamos: deposit();
        // Aquí revertimos para que el usuario use deposit()
        revert KipuBank_ZeroDeposit();
    }

    fallback() external payable {
        // rechazamos llamadas desconocidas
        revert KipuBank_ZeroDeposit();
    }
}