package com.elusivemel.orderservice.controller;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.elusivemel.orderservice.dto.OrderRequest;
import com.elusivemel.orderservice.dto.OrderResponse;
import com.elusivemel.orderservice.model.Order;
import com.elusivemel.orderservice.service.OrderService;

@RestController
@RequestMapping("/api")
public class OrderController {

    private static final Logger logger = LogManager.getLogger(OrderController.class);

    @Autowired
    private OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping("/orders/create")
    public ResponseEntity<OrderResponse> createOrder(@RequestBody OrderRequest req) {

        logger.info(req);

        Order order = orderService.createOrder(req);
        OrderResponse response = new OrderResponse(order);

        logger.info(response);

        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    @PostMapping("/orders/{id}/cancel")
    public ResponseEntity<Order> cancelOrder(@PathVariable("id") Long orderId) {

        Optional<Order> order = orderService.cancelOrder(orderId);
        if (order.isPresent()) {
            return new ResponseEntity<>(order.get(), HttpStatus.OK);
        } else {
            return new ResponseEntity<>(HttpStatus.NOT_FOUND);
        }

    }

    public void setOrderService(OrderService orderService) {
        this.orderService = orderService;
    }

    public OrderController() {
    }
}
