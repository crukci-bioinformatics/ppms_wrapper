module PPMS
  module Utilities

    def semiString2List(s)
      tags = s.split(';').map{ |t| t.strip }.select{|t| t.length > 0}
    end

    def includeProject(parent,pList)
      pList << parent.id
      Project.where(parent_id: parent.id).each do |proj|
        includeProject(proj,pList)
      end
    end

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

    def collectActivities(names)
      acts = semiString2List(names)
      ids = []
      acts.each do |act|
        ids  = ids + Enumeration.where(name: act, type: 'TimeEntryActivity').map{|x| x.id}
      end
      return ids
    end

  end
end
