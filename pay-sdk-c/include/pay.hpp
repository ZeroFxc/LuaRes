/*
 * PAY System C++ SDK
 * Object-oriented wrapper around the C API
 */
#ifndef PAY_HPP
#define PAY_HPP

#include "pay.h"
#include <string>
#include <stdexcept>

namespace pay {

/* Exception type for PAY SDK errors */
class PayException : public std::runtime_error {
public:
    explicit PayException(int code)
        : std::runtime_error(pay_error_message(code)), m_code(code) {}

    int code() const { return m_code; }

private:
    int m_code;
};

/* Configuration */
struct Config {
    std::string base_url;
    std::string api_key;
    std::string secret_key;
    std::string sign_key;    /* optional */
    std::string sec_key;     /* optional */

    /* Convert to C config */
    pay_config_t to_c() const {
        pay_config_t c = {};
        c.base_url   = base_url.empty()   ? nullptr : base_url.c_str();
        c.api_key    = api_key.empty()    ? nullptr : api_key.c_str();
        c.secret_key = secret_key.empty() ? nullptr : secret_key.c_str();
        c.sign_key   = sign_key.empty()   ? nullptr : sign_key.c_str();
        c.sec_key    = sec_key.empty()    ? nullptr : sec_key.c_str();
        return c;
    }
};

/* Order info */
struct Order {
    std::string order_id;
    double      amount = 0.0;
    std::string pay_url;
    std::string status;
    std::string order_type;

    /* Convert from C struct */
    static Order from_c(const pay_order_t& o) {
        Order order;
        order.order_id   = o.order_id;
        order.amount     = o.amount;
        order.pay_url    = o.pay_url;
        order.status     = o.status;
        order.order_type = o.order_type;
        return order;
    }
};

/* User info */
struct UserInfo {
    std::string user_id;
    std::string api_key;
    std::string username;
    double      balance = 0.0;

    static UserInfo from_c(const pay_user_info_t& u) {
        UserInfo info;
        info.user_id  = u.user_id;
        info.api_key  = u.api_key;
        info.username = u.username;
        info.balance  = u.balance;
        return info;
    }
};

/* Main client class */
class PayClient {
public:
    explicit PayClient(const Config& config) {
        pay_config_t c = config.to_c();
        int err = pay_init(&c);
        if (err != PAY_OK) {
            throw PayException(err);
        }
    }

    ~PayClient() {
        pay_cleanup();
    }

    /* Non-copyable (manages global C state) */
    PayClient(const PayClient&) = delete;
    PayClient& operator=(const PayClient&) = delete;

    /* Create a payment order */
    Order createOrder(double amount, const std::string& productName = "") {
        pay_order_t order = {};
        int err = pay_create_order(amount, productName.c_str(), &order);
        if (err != PAY_OK) throw PayException(err);
        return Order::from_c(order);
    }

    /* Query order status */
    Order queryOrder(const std::string& orderId) {
        pay_order_t order = {};
        int err = pay_query_order(orderId.c_str(), &order);
        if (err != PAY_OK) throw PayException(err);
        return Order::from_c(order);
    }

    /* Poll order until completed or timeout.
       Returns when status is "completed".
       Throws PayException(PAY_ERR_TIMEOUT) on timeout,
              PayException(PAY_ERR_API) if expired. */
    Order pollOrder(const std::string& orderId,
                    int intervalSec = 3, int maxAttempts = 60) {
        pay_order_t order = {};
        int err = pay_poll_order(orderId.c_str(), intervalSec, maxAttempts, &order);
        if (err != PAY_OK) throw PayException(err);
        return Order::from_c(order);
    }

    /* Register a new user */
    UserInfo registerUser(const std::string& username, const std::string& password) {
        pay_user_info_t user = {};
        int err = pay_register_user(username.c_str(), password.c_str(), &user);
        if (err != PAY_OK) throw PayException(err);
        return UserInfo::from_c(user);
    }

    /* Login */
    UserInfo loginUser(const std::string& username, const std::string& password) {
        pay_user_info_t user = {};
        int err = pay_login_user(username.c_str(), password.c_str(), &user);
        if (err != PAY_OK) throw PayException(err);
        return UserInfo::from_c(user);
    }

    /* Get current user info */
    UserInfo getUserInfo(const std::string& userToken) {
        pay_user_info_t user = {};
        int err = pay_get_user_info(userToken.c_str(), &user);
        if (err != PAY_OK) throw PayException(err);
        return UserInfo::from_c(user);
    }

    /* Shop recharge */
    Order shopRecharge(const std::string& userToken, double amount) {
        pay_order_t order = {};
        int err = pay_shop_recharge(userToken.c_str(), amount, &order);
        if (err != PAY_OK) throw PayException(err);
        return Order::from_c(order);
    }

    /* Get last API result (for debugging) */
    std::string lastResponseBody() const {
        const pay_result_t* r = pay_last_result();
        if (r && r->body) return std::string(r->body, r->body_len);
        return "";
    }

    int lastHttpStatus() const {
        const pay_result_t* r = pay_last_result();
        return r ? r->http_status : 0;
    }

    /* SDK version */
    static std::string version() {
        return pay_version();
    }
};

} /* namespace pay */

#endif /* PAY_HPP */
