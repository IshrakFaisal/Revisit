// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark_store.dart';

// ignore_for_file: type=lint
class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, BookmarkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalUrlMeta = const VerificationMeta(
    'canonicalUrl',
  );
  @override
  late final GeneratedColumn<String> canonicalUrl = GeneratedColumn<String>(
    'canonical_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intentionMeta = const VerificationMeta(
    'intention',
  );
  @override
  late final GeneratedColumn<String> intention = GeneratedColumn<String>(
    'intention',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SourceContext, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SourceContext>($BookmarksTable.$convertersource);
  @override
  late final GeneratedColumnWithTypeConverter<TriggerContext, String> trigger =
      GeneratedColumn<String>(
        'trigger',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TriggerContext>($BookmarksTable.$convertertrigger);
  @override
  late final GeneratedColumnWithTypeConverter<Priority, String> priority =
      GeneratedColumn<String>(
        'priority',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Priority>($BookmarksTable.$converterpriority);
  @override
  late final GeneratedColumnWithTypeConverter<BookmarkStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BookmarkStatus>($BookmarksTable.$converterstatus);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<int> snoozedUntil = GeneratedColumn<int>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReminderSubmittedAtMeta =
      const VerificationMeta('lastReminderSubmittedAt');
  @override
  late final GeneratedColumn<int> lastReminderSubmittedAt =
      GeneratedColumn<int>(
        'last_reminder_submitted_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    url,
    canonicalUrl,
    title,
    intention,
    source,
    trigger,
    priority,
    status,
    createdAt,
    updatedAt,
    snoozedUntil,
    completedAt,
    lastReminderSubmittedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('canonical_url')) {
      context.handle(
        _canonicalUrlMeta,
        canonicalUrl.isAcceptableOrUnknown(
          data['canonical_url']!,
          _canonicalUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('intention')) {
      context.handle(
        _intentionMeta,
        intention.isAcceptableOrUnknown(data['intention']!, _intentionMeta),
      );
    } else if (isInserting) {
      context.missing(_intentionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_reminder_submitted_at')) {
      context.handle(
        _lastReminderSubmittedAtMeta,
        lastReminderSubmittedAt.isAcceptableOrUnknown(
          data['last_reminder_submitted_at']!,
          _lastReminderSubmittedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookmarkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      canonicalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      intention: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intention'],
      )!,
      source: $BookmarksTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      trigger: $BookmarksTable.$convertertrigger.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}trigger'],
        )!,
      ),
      priority: $BookmarksTable.$converterpriority.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}priority'],
        )!,
      ),
      status: $BookmarksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snoozed_until'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      lastReminderSubmittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_reminder_submitted_at'],
      ),
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SourceContext, String, String> $convertersource =
      const EnumNameConverter<SourceContext>(SourceContext.values);
  static JsonTypeConverter2<TriggerContext, String, String> $convertertrigger =
      const EnumNameConverter<TriggerContext>(TriggerContext.values);
  static JsonTypeConverter2<Priority, String, String> $converterpriority =
      const EnumNameConverter<Priority>(Priority.values);
  static JsonTypeConverter2<BookmarkStatus, String, String> $converterstatus =
      const EnumNameConverter<BookmarkStatus>(BookmarkStatus.values);
}

class BookmarkRow extends DataClass implements Insertable<BookmarkRow> {
  final int id;
  final String url;
  final String canonicalUrl;
  final String title;
  final String intention;
  final SourceContext source;
  final TriggerContext trigger;
  final Priority priority;
  final BookmarkStatus status;
  final int createdAt;
  final int updatedAt;
  final int? snoozedUntil;
  final int? completedAt;
  final int? lastReminderSubmittedAt;
  const BookmarkRow({
    required this.id,
    required this.url,
    required this.canonicalUrl,
    required this.title,
    required this.intention,
    required this.source,
    required this.trigger,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.snoozedUntil,
    this.completedAt,
    this.lastReminderSubmittedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['url'] = Variable<String>(url);
    map['canonical_url'] = Variable<String>(canonicalUrl);
    map['title'] = Variable<String>(title);
    map['intention'] = Variable<String>(intention);
    {
      map['source'] = Variable<String>(
        $BookmarksTable.$convertersource.toSql(source),
      );
    }
    {
      map['trigger'] = Variable<String>(
        $BookmarksTable.$convertertrigger.toSql(trigger),
      );
    }
    {
      map['priority'] = Variable<String>(
        $BookmarksTable.$converterpriority.toSql(priority),
      );
    }
    {
      map['status'] = Variable<String>(
        $BookmarksTable.$converterstatus.toSql(status),
      );
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<int>(snoozedUntil);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    if (!nullToAbsent || lastReminderSubmittedAt != null) {
      map['last_reminder_submitted_at'] = Variable<int>(
        lastReminderSubmittedAt,
      );
    }
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      url: Value(url),
      canonicalUrl: Value(canonicalUrl),
      title: Value(title),
      intention: Value(intention),
      source: Value(source),
      trigger: Value(trigger),
      priority: Value(priority),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      lastReminderSubmittedAt: lastReminderSubmittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReminderSubmittedAt),
    );
  }

  factory BookmarkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkRow(
      id: serializer.fromJson<int>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      canonicalUrl: serializer.fromJson<String>(json['canonicalUrl']),
      title: serializer.fromJson<String>(json['title']),
      intention: serializer.fromJson<String>(json['intention']),
      source: $BookmarksTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      trigger: $BookmarksTable.$convertertrigger.fromJson(
        serializer.fromJson<String>(json['trigger']),
      ),
      priority: $BookmarksTable.$converterpriority.fromJson(
        serializer.fromJson<String>(json['priority']),
      ),
      status: $BookmarksTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      snoozedUntil: serializer.fromJson<int?>(json['snoozedUntil']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      lastReminderSubmittedAt: serializer.fromJson<int?>(
        json['lastReminderSubmittedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'url': serializer.toJson<String>(url),
      'canonicalUrl': serializer.toJson<String>(canonicalUrl),
      'title': serializer.toJson<String>(title),
      'intention': serializer.toJson<String>(intention),
      'source': serializer.toJson<String>(
        $BookmarksTable.$convertersource.toJson(source),
      ),
      'trigger': serializer.toJson<String>(
        $BookmarksTable.$convertertrigger.toJson(trigger),
      ),
      'priority': serializer.toJson<String>(
        $BookmarksTable.$converterpriority.toJson(priority),
      ),
      'status': serializer.toJson<String>(
        $BookmarksTable.$converterstatus.toJson(status),
      ),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'snoozedUntil': serializer.toJson<int?>(snoozedUntil),
      'completedAt': serializer.toJson<int?>(completedAt),
      'lastReminderSubmittedAt': serializer.toJson<int?>(
        lastReminderSubmittedAt,
      ),
    };
  }

  BookmarkRow copyWith({
    int? id,
    String? url,
    String? canonicalUrl,
    String? title,
    String? intention,
    SourceContext? source,
    TriggerContext? trigger,
    Priority? priority,
    BookmarkStatus? status,
    int? createdAt,
    int? updatedAt,
    Value<int?> snoozedUntil = const Value.absent(),
    Value<int?> completedAt = const Value.absent(),
    Value<int?> lastReminderSubmittedAt = const Value.absent(),
  }) => BookmarkRow(
    id: id ?? this.id,
    url: url ?? this.url,
    canonicalUrl: canonicalUrl ?? this.canonicalUrl,
    title: title ?? this.title,
    intention: intention ?? this.intention,
    source: source ?? this.source,
    trigger: trigger ?? this.trigger,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    lastReminderSubmittedAt: lastReminderSubmittedAt.present
        ? lastReminderSubmittedAt.value
        : this.lastReminderSubmittedAt,
  );
  BookmarkRow copyWithCompanion(BookmarksCompanion data) {
    return BookmarkRow(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      canonicalUrl: data.canonicalUrl.present
          ? data.canonicalUrl.value
          : this.canonicalUrl,
      title: data.title.present ? data.title.value : this.title,
      intention: data.intention.present ? data.intention.value : this.intention,
      source: data.source.present ? data.source.value : this.source,
      trigger: data.trigger.present ? data.trigger.value : this.trigger,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      lastReminderSubmittedAt: data.lastReminderSubmittedAt.present
          ? data.lastReminderSubmittedAt.value
          : this.lastReminderSubmittedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkRow(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('canonicalUrl: $canonicalUrl, ')
          ..write('title: $title, ')
          ..write('intention: $intention, ')
          ..write('source: $source, ')
          ..write('trigger: $trigger, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('completedAt: $completedAt, ')
          ..write('lastReminderSubmittedAt: $lastReminderSubmittedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    url,
    canonicalUrl,
    title,
    intention,
    source,
    trigger,
    priority,
    status,
    createdAt,
    updatedAt,
    snoozedUntil,
    completedAt,
    lastReminderSubmittedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkRow &&
          other.id == this.id &&
          other.url == this.url &&
          other.canonicalUrl == this.canonicalUrl &&
          other.title == this.title &&
          other.intention == this.intention &&
          other.source == this.source &&
          other.trigger == this.trigger &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.snoozedUntil == this.snoozedUntil &&
          other.completedAt == this.completedAt &&
          other.lastReminderSubmittedAt == this.lastReminderSubmittedAt);
}

class BookmarksCompanion extends UpdateCompanion<BookmarkRow> {
  final Value<int> id;
  final Value<String> url;
  final Value<String> canonicalUrl;
  final Value<String> title;
  final Value<String> intention;
  final Value<SourceContext> source;
  final Value<TriggerContext> trigger;
  final Value<Priority> priority;
  final Value<BookmarkStatus> status;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> snoozedUntil;
  final Value<int?> completedAt;
  final Value<int?> lastReminderSubmittedAt;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.canonicalUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.intention = const Value.absent(),
    this.source = const Value.absent(),
    this.trigger = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.lastReminderSubmittedAt = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String url,
    required String canonicalUrl,
    required String title,
    required String intention,
    required SourceContext source,
    required TriggerContext trigger,
    required Priority priority,
    required BookmarkStatus status,
    required int createdAt,
    required int updatedAt,
    this.snoozedUntil = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.lastReminderSubmittedAt = const Value.absent(),
  }) : url = Value(url),
       canonicalUrl = Value(canonicalUrl),
       title = Value(title),
       intention = Value(intention),
       source = Value(source),
       trigger = Value(trigger),
       priority = Value(priority),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookmarkRow> custom({
    Expression<int>? id,
    Expression<String>? url,
    Expression<String>? canonicalUrl,
    Expression<String>? title,
    Expression<String>? intention,
    Expression<String>? source,
    Expression<String>? trigger,
    Expression<String>? priority,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? snoozedUntil,
    Expression<int>? completedAt,
    Expression<int>? lastReminderSubmittedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (canonicalUrl != null) 'canonical_url': canonicalUrl,
      if (title != null) 'title': title,
      if (intention != null) 'intention': intention,
      if (source != null) 'source': source,
      if (trigger != null) 'trigger': trigger,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (completedAt != null) 'completed_at': completedAt,
      if (lastReminderSubmittedAt != null)
        'last_reminder_submitted_at': lastReminderSubmittedAt,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? url,
    Value<String>? canonicalUrl,
    Value<String>? title,
    Value<String>? intention,
    Value<SourceContext>? source,
    Value<TriggerContext>? trigger,
    Value<Priority>? priority,
    Value<BookmarkStatus>? status,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? snoozedUntil,
    Value<int?>? completedAt,
    Value<int?>? lastReminderSubmittedAt,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      title: title ?? this.title,
      intention: intention ?? this.intention,
      source: source ?? this.source,
      trigger: trigger ?? this.trigger,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      completedAt: completedAt ?? this.completedAt,
      lastReminderSubmittedAt:
          lastReminderSubmittedAt ?? this.lastReminderSubmittedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (canonicalUrl.present) {
      map['canonical_url'] = Variable<String>(canonicalUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (intention.present) {
      map['intention'] = Variable<String>(intention.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $BookmarksTable.$convertersource.toSql(source.value),
      );
    }
    if (trigger.present) {
      map['trigger'] = Variable<String>(
        $BookmarksTable.$convertertrigger.toSql(trigger.value),
      );
    }
    if (priority.present) {
      map['priority'] = Variable<String>(
        $BookmarksTable.$converterpriority.toSql(priority.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $BookmarksTable.$converterstatus.toSql(status.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<int>(snoozedUntil.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (lastReminderSubmittedAt.present) {
      map['last_reminder_submitted_at'] = Variable<int>(
        lastReminderSubmittedAt.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('canonicalUrl: $canonicalUrl, ')
          ..write('title: $title, ')
          ..write('intention: $intention, ')
          ..write('source: $source, ')
          ..write('trigger: $trigger, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('completedAt: $completedAt, ')
          ..write('lastReminderSubmittedAt: $lastReminderSubmittedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$BookmarkStore extends GeneratedDatabase {
  _$BookmarkStore(QueryExecutor e) : super(e);
  $BookmarkStoreManager get managers => $BookmarkStoreManager(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [bookmarks];
}

typedef $$BookmarksTableCreateCompanionBuilder = BookmarksCompanion Function({
  Value<int> id,
  required String url,
  required String canonicalUrl,
  required String title,
  required String intention,
  required SourceContext source,
  required TriggerContext trigger,
  required Priority priority,
  required BookmarkStatus status,
  required int createdAt,
  required int updatedAt,
  Value<int?> snoozedUntil,
  Value<int?> completedAt,
  Value<int?> lastReminderSubmittedAt,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<int> id,
  Value<String> url,
  Value<String> canonicalUrl,
  Value<String> title,
  Value<String> intention,
  Value<SourceContext> source,
  Value<TriggerContext> trigger,
  Value<Priority> priority,
  Value<BookmarkStatus> status,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> snoozedUntil,
  Value<int?> completedAt,
  Value<int?> lastReminderSubmittedAt,
});

class $$BookmarksTableFilterComposer
    extends Composer<_$BookmarkStore, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intention => $composableBuilder(
    column: $table.intention,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SourceContext, SourceContext, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<TriggerContext, TriggerContext, String>
  get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Priority, Priority, String> get priority =>
      $composableBuilder(
        column: $table.priority,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<BookmarkStatus, BookmarkStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReminderSubmittedAt => $composableBuilder(
    column: $table.lastReminderSubmittedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$BookmarkStore, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intention => $composableBuilder(
    column: $table.intention,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReminderSubmittedAt => $composableBuilder(
    column: $table.lastReminderSubmittedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$BookmarkStore, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get intention =>
      $composableBuilder(column: $table.intention, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SourceContext, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TriggerContext, String> get trigger =>
      $composableBuilder(column: $table.trigger, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Priority, String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BookmarkStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastReminderSubmittedAt => $composableBuilder(
    column: $table.lastReminderSubmittedAt,
    builder: (column) => column,
  );
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$BookmarkStore,
          $BookmarksTable,
          BookmarkRow,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (
            BookmarkRow,
            BaseReferences<_$BookmarkStore, $BookmarksTable, BookmarkRow>,
          ),
          BookmarkRow,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$BookmarkStore db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> canonicalUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> intention = const Value.absent(),
                Value<SourceContext> source = const Value.absent(),
                Value<TriggerContext> trigger = const Value.absent(),
                Value<Priority> priority = const Value.absent(),
                Value<BookmarkStatus> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> snoozedUntil = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int?> lastReminderSubmittedAt = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                url: url,
                canonicalUrl: canonicalUrl,
                title: title,
                intention: intention,
                source: source,
                trigger: trigger,
                priority: priority,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                snoozedUntil: snoozedUntil,
                completedAt: completedAt,
                lastReminderSubmittedAt: lastReminderSubmittedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String url,
                required String canonicalUrl,
                required String title,
                required String intention,
                required SourceContext source,
                required TriggerContext trigger,
                required Priority priority,
                required BookmarkStatus status,
                required int createdAt,
                required int updatedAt,
                Value<int?> snoozedUntil = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int?> lastReminderSubmittedAt = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                url: url,
                canonicalUrl: canonicalUrl,
                title: title,
                intention: intention,
                source: source,
                trigger: trigger,
                priority: priority,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                snoozedUntil: snoozedUntil,
                completedAt: completedAt,
                lastReminderSubmittedAt: lastReminderSubmittedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookmarksTable, BookmarkRow>(table),
                  BaseReferences<_$BookmarkStore, $BookmarksTable, BookmarkRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$BookmarkStore,
      $BookmarksTable,
      BookmarkRow,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (
        BookmarkRow,
        BaseReferences<_$BookmarkStore, $BookmarksTable, BookmarkRow>,
      ),
      BookmarkRow,
      PrefetchHooks Function()
    >;

class $BookmarkStoreManager {
  final _$BookmarkStore _db;
  $BookmarkStoreManager(this._db);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
}
