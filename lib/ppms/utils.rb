module PPMS
  module Utilities

    def semiString2List(s)
      s.split(';').map{ |t| t.strip }.select{|t| t.length > 0}
    end

    def includeProject(parent,pList)
      pList << parent.id
      Project.where(parent_id: parent.id).each do |proj|
        includeProject(proj,pList)
      end
    end

    # Get the ids of root projects given by names and the ids of all
    # subprojects from those roots.
    def collectProjects(names)
      roots = semiString2List(names)
      projList = Array.new
      roots.each do |root|
        Project.where(name: root).each do |p|
          includeProject(p,projList)
        end
      end
      return projList
    end

    # Get the ids of root projects given by names without collecting
    # subprojects.
    def getRootProjects(names)
      roots = semiString2List(names)
      projList = Array.new
      roots.each do |root|
        Project.where(name: root).each do |p|
          projList << p.id
        end
      end
      return projList
    end

    def collectActivities(names)
      acts = semiString2List(names)
      ids = []
      acts.each do |act|
        ids  = ids + Enumeration.where(name: act, type: 'TimeEntryActivity').map{|x| x.id}
      end
      return ids
    end

    def isAncestor(ancestor,child)
      parent = child.parent_id
      while not parent.nil? and parent != ancestor.id
        child = Project.find(parent)
        parent = child.parent_id
      end
      return (not parent.nil?)
    end

    def reduceProjSet(pset)
      npset = Set.new
      pset.each do |proj|
        hasAncestor = pset.map{|p| isAncestor(p,proj) ? 1 : 0}.sum > 0
        if not hasAncestor
          npset.add(proj)
        end
      end
      return npset
    end

  end
end
