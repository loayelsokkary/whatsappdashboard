import 'package:flutter/material.dart';
import '../theme/vivid_theme.dart';

// ============================================
// TRANSACTION TYPE
// ============================================

enum TransactionType {
  income,
  expense;

  String get label => switch (this) {
        income => 'Income',
        expense => 'Expense',
      };

  String get dbValue => switch (this) {
        income => 'income',
        expense => 'expense',
      };

  Color get color => switch (this) {
        income => VividColors.statusSuccess,
        expense => VividColors.statusUrgent,
      };

  static TransactionType fromDb(String? value) => switch (value) {
        'expense' => expense,
        _ => income,
      };
}

// ============================================
// PAYMENT STATUS
// ============================================

enum PaymentStatus {
  pending,
  paid,
  overdue,
  cancelled;

  String get label => switch (this) {
        pending => 'Pending',
        paid => 'Paid',
        overdue => 'Overdue',
        cancelled => 'Cancelled',
      };

  String get dbValue => switch (this) {
        pending => 'pending',
        paid => 'paid',
        overdue => 'overdue',
        cancelled => 'cancelled',
      };

  Color get color => switch (this) {
        pending => VividColors.statusWarning,
        paid => VividColors.statusSuccess,
        overdue => VividColors.statusUrgent,
        cancelled => Colors.grey,
      };

  static PaymentStatus fromDb(String? value) => switch (value) {
        'paid' => paid,
        'overdue' => overdue,
        'cancelled' => cancelled,
        _ => pending,
      };
}

// ============================================
// CATEGORY HELPERS
// ============================================

class FinancialCategories {
  static const List<String> income = [
    'Monthly Subscription',
    'Setup Fee',
    'Custom Development',
    'Broadcast Credits',
    'Other',
  ];

  static const List<String> expense = [
    'Server Costs',
    'API Costs',
    'Software',
    'Marketing',
    'Staff',
    'Other',
  ];
}

// ============================================
// DATE RANGE PRESETS
// ============================================

enum DateRangePreset {
  thisMonth,
  lastMonth,
  thisQuarter,
  thisYear,
  allTime,
  custom;

  String get label => switch (this) {
        thisMonth => 'This Month',
        lastMonth => 'Last Month',
        thisQuarter => 'This Quarter',
        thisYear => 'This Year',
        allTime => 'All Time',
        custom => 'Custom',
      };
}

// ============================================
// FINANCIAL TRANSACTION
// ============================================

class FinancialTransaction {
  final String id;
  final String? clientId;
  final String? clientName;
  final TransactionType type;
  final String? category;
  final double amount;
  final String currency;
  final String? description;
  final String? invoiceNumber;
  final PaymentStatus paymentStatus;
  final DateTime? dueDate;
  final DateTime? paidDate;
  final bool recurring;
  final String? recurringInterval;
  final Map<String, dynamic>? metadata;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FinancialTransaction({
    required this.id,
    this.clientId,
    this.clientName,
    required this.type,
    this.category,
    required this.amount,
    this.currency = 'BHD',
    this.description,
    this.invoiceNumber,
    this.paymentStatus = PaymentStatus.pending,
    this.dueDate,
    this.paidDate,
    this.recurring = false,
    this.recurringInterval,
    this.metadata,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) {
    // Handle joined client data
    String? clientName;
    if (json['clients'] is Map) {
      clientName = (json['clients'] as Map)['name'] as String?;
    }

    return FinancialTransaction(
      id: json['id'] as String? ?? '',
      clientId: json['client_id'] as String?,
      clientName: clientName,
      type: TransactionType.fromDb(json['type'] as String?),
      category: json['category'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'BHD',
      description: json['description'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      paymentStatus: PaymentStatus.fromDb(json['payment_status'] as String?),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      paidDate: json['paid_date'] != null
          ? DateTime.tryParse(json['paid_date'].toString())
          : null,
      recurring: json['recurring'] as bool? ?? false,
      recurringInterval: json['recurring_interval'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        if (clientId != null) 'client_id': clientId,
        'type': type.dbValue,
        'category': category,
        'amount': amount,
        'currency': currency,
        'description': description,
        'invoice_number': invoiceNumber,
        'payment_status': paymentStatus.dbValue,
        if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
        if (paidDate != null) 'paid_date': paidDate!.toIso8601String(),
        'recurring': recurring,
        'recurring_interval': recurringInterval,
        if (metadata != null) 'metadata': metadata,
        if (createdBy != null) 'created_by': createdBy,
      };
}
