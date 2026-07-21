bool isHandoverCompletedProject(Map<String, dynamic>? project) {
  if (project == null) return false;
  return (project['handover_status'] ?? '').toString().toLowerCase() ==
      'approved';
}

bool shouldHideHandoverCompletedForEmployee(String? role) {
  return (role ?? '').toLowerCase() == 'nhan_vien';
}

List<Map<String, dynamic>> filterProjectsForEmployee(
  List<Map<String, dynamic>> projects,
  String? role,
) {
  if (!shouldHideHandoverCompletedForEmployee(role)) {
    return projects;
  }

  return projects
      .where((project) => !isHandoverCompletedProject(project))
      .toList();
}

List<Map<String, dynamic>> filterTasksForEmployee(
  List<Map<String, dynamic>> tasks,
  String? role,
) {
  if (!shouldHideHandoverCompletedForEmployee(role)) {
    return tasks;
  }

  return tasks.where((task) {
    final project = task['project'];
    if (project is! Map) {
      return true;
    }

    return !isHandoverCompletedProject(Map<String, dynamic>.from(project));
  }).toList();
}

List<Map<String, dynamic>> filterTaskItemsForEmployee(
  List<Map<String, dynamic>> items,
  String? role,
) {
  if (!shouldHideHandoverCompletedForEmployee(role)) {
    return items;
  }

  return items.where((item) {
    final task = item['task'];
    if (task is! Map) {
      return true;
    }

    final project = task['project'];
    if (project is! Map) {
      return true;
    }

    return !isHandoverCompletedProject(Map<String, dynamic>.from(project));
  }).toList();
}
